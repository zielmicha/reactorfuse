import reactor/async, reactor/process, reactor/ipc, reactor/loop, reactor/util, future
import reactorfuse/fuse_kernel
import posix, options

include reactorfuse/linux

type
  Attributes* = fuse_attr

  RequestKind* = enum
    fuseLookup, fuseGetAttr, fuseForget, fuseOpen

  NodeId* = uint64

  Request* = ref object
    nodeId*: NodeId
    uid*: uint32
    gid*: uint32
    pid*: uint32
    reqId: uint64

    case kind: RequestKind:
    of fuseLookup:
      lookupName: string
    of fuseForget:
      forgetNodeId: NodeId
    of fuseOpen:
      isDir: bool
      flags: uint32
      mode: uint32
    of fuseGetAttr:
      discard

  FuseConnection* = ref object
    fakePipe: IpcPipe
    pipe: Pipe[string]
    requests*: Stream[Request]

  Time* = object
    sec: uint64
    nsec: uint32

const
  forever = Time(sec: (-1).uint64)

proc unpackSecondHeader[T](item: string, t: typedesc[T]): T =
  unpackStruct(item[sizeof(fuse_in_header)..<sizeof(fuse_in_header) + sizeof(T)], T)

proc respond(conn: FuseConnection, req: Request, data: string, error: cint=0): Future[void] =
  let header = packStruct(fuse_out_header(
    len: (sizeof(fuse_out_header) + data.len).uint32,
    error: error.int32,
    unique: req.reqId
  ))
  return conn.pipe.output.provide(header & data)

proc respond[T](conn: FuseConnection, req: Request, data: T, error: cint=0): Future[void] =
  conn.respond(req, packStruct(data), error)

proc respondToGetAttr(conn: FuseConnection, req: Request, attr: Attributes, attrTimeout=Time()): Future[void] =
  assert req.kind == fuseGetAttr
  conn.respond(req, fuse_attr_out(attr_valid: attrTimeout.sec, attr_valid_nsec: attrTimeout.nsec, attr: attr))

proc respondToLookup(conn: FuseConnection, req: Request, newNodeId: NodeId, attr: Attributes,
                     attrTimeout: Time=Time(), entryTimeout: Time=forever, generation: uint64=0): Future[void] =
  assert req.kind == fuseGetAttr
  conn.respond(req, fuse_entry_out(attr_valid: attrTimeout.sec,
                                   attr_valid_nsec: attrTimeout.nsec,
                                   entry_valid: entryTimeout.sec,
                                   entry_valid_nsec: entryTimeout.nsec,
                                   generation: generation,
                                   attr: attr,
                                   nodeid: newNodeId))

proc respondToOpen(conn: FuseConnection, req: Request, fileHandle: uint64, keepCache=false): Future[void] =
  assert req.kind == fuseOpen
  conn.respond(req, fuse_open_out(fh: fileHandle, open_flags: if keepCache: FOPEN_KEEP_CACHE else: 0))

proc respondError(conn: FuseConnection, req: Request, code: cint): Future[void] =
  assert req.kind != fuseForget
  conn.respond(req, "", error=(-code))

proc translateMsg(conn: FuseConnection, item: string): Future[Option[Request]] {.async.} =
  let header = unpackStruct(item, fuse_in_header)
  let req = Request(nodeId: header.nodeid, uid: header.uid, gid: header.gid, pid: header.pid, reqId: header.unique)
  let kind = header.opcode.fuse_opcode
  let rest = item[sizeof(fuse_in_header)..^1]

  echo "req: ", kind

  case kind:
  of FUSE_GETATTR:
    req.kind = fuseGetAttr
  of FUSE_LOOKUP:
    req.kind = fuseLookup
    req.lookupName = rest.cstring.`$`
  of FUSE_FORGET:
    req.kind = fuseForget
  of {FUSE_OPEN, FUSE_OPENDIR}:
    req.kind = fuseOpen
    req.isDir = kind == FUSE_OPENDIR
    let info = unpackStruct(rest, fuse_open_in)
    req.flags = info.flags
    req.mode = info.mode
  else:
    await conn.respondError(req, ENOSYS)
    asyncReturn none(Request)

  asyncReturn some(req)

proc handleInit(conn: FuseConnection) {.async.} =
  let initData = await conn.pipe.input.receive()
  let init = unpackStruct(initData, fuse_in_header)
  if init.opcode.fuse_opcode != FUSE_INIT:
    asyncRaise "bad FUSE initial message"

  let initReq = unpackStruct(initData[sizeof(fuse_in_header)..^1], fuse_init_in)

  if initReq.major < FUSE_KERNEL_VERSION:
    asyncRaise "kernel too old"

  var initResp = fuse_init_out(major: FUSE_KERNEL_VERSION,
                               minor: FUSE_KERNEL_MINOR_VERSION,
                               max_write: 64 * 1024,
                               max_readahead: 64 * 1024 * 1024,
                               flags: FUSE_ASYNC_READ)
  let initRespS = packStruct(initResp)
  var initRespHeader = fuse_out_header(len: (initRespS.len + sizeof(fuse_out_header)).uint32, error: 0.int32, unique: init.unique)
  let initRespHeaderS = packStruct(initRespHeader)

  await conn.pipe.output.provide(initRespHeaderS & initRespS)

proc setup(pipe: IpcPipe): FuseConnection =
  let conn = FuseConnection(fakePipe: pipe, pipe: newMsgPipe(pipe.fileno))

  proc getRequests(): Stream[Request] {.asyncIterator.} =
    await conn.handleInit()
    echo "FUSE init ok"

    asyncFor item in conn.pipe.input:
      let req = await conn.translateMsg(item)
      if req.isSome:
        asyncYield req.get

  conn.requests = getRequests()

  return conn

proc mount*(dir: string, options: MountConfig): Future[FuseConnection] =
  rawMount(dir, options).then(x => x.setup())

when isMainModule:
  proc main() {.async.} =
    let conn = await mount("/home/michal/mnt", ())
    while true:
      let msg = await conn.requests.receive()
      echo "recv ", msg.repr

      if msg.kind == fuseGetAttr:
        await conn.respondToGetAttr(msg, Attributes(mode: 0o40750))
      else:
        await conn.respondError(msg, ENOSYS)

  main().runLoop()

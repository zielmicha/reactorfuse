import reactor/async, reactor/process, reactor/ipc, reactor/loop
import posix, os

type
  MountConfig* = tuple

proc getOptions(conf: MountConfig): string =
  "rw"

proc rawMount*(dir: string, config: MountConfig): Future[IpcPipe] {.async.} =
  var fds: array[2, cint]
  if posix.socketpair(AF_UNIX, SOCK_STREAM, 0, fds) < 0:
    raiseOSError(osLastError())

  let command = @["fusermount", "-o", config.getOptions, "--", dir]

  let helperPipe = fromPipeFd(fds[1], ipc=true)
  let process = startProcess(command,
                             additionalEnv={"_FUSE_COMMFD": "3"},
                             additionalFiles={3.cint: fds[0]})

  await process.waitForSuccess()
  discard close(fds[0])
  discard (await helperPipe.input.receive())
  helperPipe.input.recvClose(JustClose)
  helperPipe.output.sendClose(JustClose)
  let pipe = await helperPipe.getPendingHandle(paused=true)
  asyncReturn pipe

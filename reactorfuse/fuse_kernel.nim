#* Version number of this interface

const
  FUSE_KERNEL_VERSION* = 7

#* Minor version number of this interface 

const
  FUSE_KERNEL_MINOR_VERSION* = 8

#* The node ID of the root inode 

const
  FUSE_ROOT_ID* = 1

#* The major number of the fuse character device 

const
  FUSE_MAJOR* = 10

#* The minor number of the fuse character device 

const
  FUSE_MINOR* = 229

# Make sure all structures are padded to 64bit boundary, so 32bit
#   userspace works under 64bit kernels 

type
  fuse_attr* = object
    ino*: uint64
    size*: uint64
    blocks*: uint64
    atime*: uint64
    mtime*: uint64
    ctime*: uint64
    atimensec*: uint32
    mtimensec*: uint32
    ctimensec*: uint32
    mode*: uint32
    nlink*: uint32
    uid*: uint32
    gid*: uint32
    rdev*: uint32

  fuse_kstatfs* = object
    blocks*: uint64
    bfree*: uint64
    bavail*: uint64
    files*: uint64
    ffree*: uint64
    bsize*: uint32
    namelen*: uint32
    frsize*: uint32
    padding*: uint32
    spare*: array[6, uint32]

  fuse_file_lock* = object
    start*: uint64
    `end`*: uint64
    `type`*: uint32
    pid*: uint32                # tgid
  

#*
#  Bitmasks for fuse_setattr_in.valid
# 

const
  FATTR_MODE* = (1 shl 0)
  FATTR_UID* = (1 shl 1)
  FATTR_GID* = (1 shl 2)
  FATTR_SIZE* = (1 shl 3)
  FATTR_ATIME* = (1 shl 4)
  FATTR_MTIME* = (1 shl 5)
  FATTR_FH* = (1 shl 6)

#*
#  Flags returned by the OPEN request
# 
#  FOPEN_DIRECT_IO: bypass page cache for this open file
#  FOPEN_KEEP_CACHE: don't invalidate the data cache on open
# 

const
  FOPEN_DIRECT_IO* = (1 shl 0)
  FOPEN_KEEP_CACHE* = (1 shl 1)

#*
#  INIT request/reply flags
# 

const
  FUSE_ASYNC_READ* = (1 shl 0)
  FUSE_POSIX_LOCKS* = (1 shl 1)

#*
#  Release flags
# 

const
  FUSE_RELEASE_FLUSH* = (1 shl 0)

type
  fuse_opcode* = enum
    FUSE_LOOKUP = 1, FUSE_FORGET = 2, # no reply 
    FUSE_GETATTR = 3, FUSE_SETATTR = 4, FUSE_READLINK = 5, FUSE_SYMLINK = 6, FUSE_MKNOD = 8,
    FUSE_MKDIR = 9, FUSE_UNLINK = 10, FUSE_RMDIR = 11, FUSE_RENAME = 12, FUSE_LINK = 13,
    FUSE_OPEN = 14, FUSE_READ = 15, FUSE_WRITE = 16, FUSE_STATFS = 17, FUSE_RELEASE = 18,
    FUSE_FSYNC = 20, FUSE_SETXATTR = 21, FUSE_GETXATTR = 22, FUSE_LISTXATTR = 23,
    FUSE_REMOVEXATTR = 24, FUSE_FLUSH = 25, FUSE_INIT = 26, FUSE_OPENDIR = 27,
    FUSE_READDIR = 28, FUSE_RELEASEDIR = 29, FUSE_FSYNCDIR = 30, FUSE_GETLK = 31,
    FUSE_SETLK = 32, FUSE_SETLKW = 33, FUSE_ACCESS = 34, FUSE_CREATE = 35,
    FUSE_INTERRUPT = 36, FUSE_BMAP = 37, FUSE_DESTROY = 38


# The read buffer is required to be at least 8k, but may be much larger 

const
  FUSE_MIN_READ_BUFFER* = 8192

type
  fuse_entry_out* = object
    nodeid*: uint64             # Inode ID
    generation*: uint64         # Inode generation: nodeid:gen must
                     #                   be unique for the fs's lifetime 
    entry_valid*: uint64        # Cache timeout for the name
    attr_valid*: uint64         # Cache timeout for the attributes
    entry_valid_nsec*: uint32
    attr_valid_nsec*: uint32
    attr*: fuse_attr

  fuse_forget_in* = object
    nlookup*: uint64

  fuse_attr_out* = object
    attr_valid*: uint64         # Cache timeout for the attributes
    attr_valid_nsec*: uint32
    dummy*: uint32
    attr*: fuse_attr

  fuse_mknod_in* = object
    mode*: uint32
    rdev*: uint32

  fuse_mkdir_in* = object
    mode*: uint32
    padding*: uint32

  fuse_rename_in* = object
    newdir*: uint64

  fuse_link_in* = object
    oldnodeid*: uint64

  fuse_setattr_in* = object
    valid*: uint32
    padding*: uint32
    fh*: uint64
    size*: uint64
    unused1*: uint64
    atime*: uint64
    mtime*: uint64
    unused2*: uint64
    atimensec*: uint32
    mtimensec*: uint32
    unused3*: uint32
    mode*: uint32
    unused4*: uint32
    uid*: uint32
    gid*: uint32
    unused5*: uint32

  fuse_open_in* = object
    flags*: uint32
    mode*: uint32

  fuse_open_out* = object
    fh*: uint64
    open_flags*: uint32
    padding*: uint32

  fuse_release_in* = object
    fh*: uint64
    flags*: uint32
    release_flags*: uint32
    lock_owner*: uint64

  fuse_flush_in* = object
    fh*: uint64
    unused*: uint32
    padding*: uint32
    lock_owner*: uint64

  fuse_read_in* = object
    fh*: uint64
    offset*: uint64
    size*: uint32
    padding*: uint32

  fuse_write_in* = object
    fh*: uint64
    offset*: uint64
    size*: uint32
    write_flags*: uint32

  fuse_write_out* = object
    size*: uint32
    padding*: uint32


const
  FUSE_COMPAT_STATFS_SIZE* = 48

type
  fuse_statfs_out* = object
    st*: fuse_kstatfs

  fuse_fsync_in* = object
    fh*: uint64
    fsync_flags*: uint32
    padding*: uint32

  fuse_setxattr_in* = object
    size*: uint32
    flags*: uint32

  fuse_getxattr_in* = object
    size*: uint32
    padding*: uint32

  fuse_getxattr_out* = object
    size*: uint32
    padding*: uint32

  fuse_lk_in* = object
    fh*: uint64
    owner*: uint64
    lk*: fuse_file_lock

  fuse_lk_out* = object
    lk*: fuse_file_lock

  fuse_access_in* = object
    mask*: uint32
    padding*: uint32

  fuse_init_in* = object
    major*: uint32
    minor*: uint32
    max_readahead*: uint32
    flags*: uint32

  fuse_init_out* = object
    major*: uint32
    minor*: uint32
    max_readahead*: uint32
    flags*: uint32
    unused*: uint32
    max_write*: uint32

  fuse_interrupt_in* = object
    unique*: uint64

  fuse_bmap_in* = object
    `block`*: uint64
    blocksize*: uint32
    padding*: uint32

  fuse_bmap_out* = object
    `block`*: uint64

  fuse_in_header* = object
    len*: uint32
    opcode*: uint32
    unique*: uint64
    nodeid*: uint64
    uid*: uint32
    gid*: uint32
    pid*: uint32
    padding*: uint32

  fuse_out_header* = object
    len*: uint32
    error*: int32
    unique*: uint64

  fuse_dirent* = object
    ino*: uint64
    off*: uint64
    namelen*: uint32
    `type`*: uint32

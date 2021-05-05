from talon import resource, Module, Context, fs
import os

mod = Module()
ctx = Context()

mod.list("emacs_buffers", desc="names for all emacs buffers")

EMACS_DIRECTORY = os.path.expanduser("~/.emacs.d/")
PATH = os.path.join(EMACS_DIRECTORY, "talon-buffer-list")

buffer_names = []

def update_buffer_names(name, _flags):
    global buffer_names
    if name != PATH: return
    print("*** RELOADING EMACS BUFFER LIST ***")
    with open(PATH, "r") as f:
        buffer_names = [s.rstrip('\n') for s in f.readlines()]
    print(f"buffer_names[:2] = {buffer_names[:2]}")
    ctx.lists["user.emacs_buffers"] = buffer_names

update_buffer_names(PATH, "")
fs.watch(EMACS_DIRECTORY, update_buffer_names)

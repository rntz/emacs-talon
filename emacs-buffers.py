from talon import resource, Module, Context, fs, actions, ui
import os, subprocess, logging

mod = Module()
ctx = Context()

mod.list("emacs_buffers", desc="names for all emacs buffers")

EMACS_DIRECTORY = os.path.expanduser("~/.emacs.d")
PATH = os.path.join(EMACS_DIRECTORY, "talon-buffer-list")

buffer_names = []

def update_buffer_names(name, _flags):
    global buffer_names
    #print(name, _flags)
    if name != PATH: return
    logging.info("Reloading emacs buffer list")
    with open(PATH, "r") as f:
        buffer_names = [s.rstrip('\n') for s in f.readlines()]
    # print(f"buffer_names[:2] = {buffer_names[:2]}")
    # print(f"len(buffer_names) = {len(buffer_names)}")
    ctx.lists["user.emacs_buffers"] = buffer_names

update_buffer_names(PATH, None)
fs.watch(EMACS_DIRECTORY, update_buffer_names)

@mod.action_class
class buffer_actions:
    def emacs_elisp(code: str):
        """Make emacs run some elisp code."""
        subprocess.Popen(["emacsclient", "-e", code])

    def emacs_open_buffer(spoken_form: str):
        """Switches to a buffer by its spoken form, focusing or creating an emacs window on the current desktop as appropriate."""
        try:
            current_workspace = ui.active_workspace()
            active_window = ui.active_window()
            emacs = actions.user.get_running_app("Emacs")
            ws = [w for w in emacs.windows() if w.workspace == current_workspace]
            ws[0].focus() # deliberately causes exception if empty
        except:
            ui.launch(path="emacsclient", args=["-ce", f'(talon-switch "{spoken_form}")'])
            actions.sleep("400ms")
            actions.user.switcher_focus("Emacs")
        else:
            actions.user.emacs_elisp(f'(talon-switch "{spoken_form}")')

    def emacs_buffer_select(spoken_form: str):
        """Switch to a buffer by its spoken form."""
        actions.user.switcher_focus("Emacs")
        actions.user.emacs_elisp(f'(talon-switch "{spoken_form}")')

    def emacs_buffer_select_other(spoken_form: str):
        """Switch to a buffer by its spoken form in other tab."""
        actions.user.switcher_focus("Emacs")
        actions.user.emacs_elisp(f'(talon-switch-other-window "{spoken_form}")')

emacs_context = Context()
emacs_context.matches = '''app: Emacs'''
@emacs_context.action_class('user')
class emacs_buffer_actions:
    def emacs_open_buffer(spoken_form):
        actions.key('f12 o')
        actions.insert(spoken_form + '\n')

    def emacs_buffer_select(spoken_form):
        actions.key('f12 b')
        actions.insert(spoken_form + '\n')

    def emacs_buffer_select_other(spoken_form):
        actions.key('f12 o')
        actions.insert(spoken_form + '\n')

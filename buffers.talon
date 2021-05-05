emacs buffer {user.emacs_buffers}: "EMACS BUFFER {emacs_buffers}"
emacs send {user.emacs_buffers}$:
  user.system_command_nb("emacsclient -e '(respond-to-talon \"{emacs_buffers}\")'")

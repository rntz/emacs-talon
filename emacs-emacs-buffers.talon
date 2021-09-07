app: Emacs
-
switch <user.letter> instead: key("f12 a {letter}")
switch more: key("f12 a !")
talon update buffers: user.emacs_command("tal-up")

switch {user.emacs_buffers} [go] top:
  user.emacs_buffer_select(emacs_buffers)
  edit.file_start()
switch {user.emacs_buffers} [go] bottom:
  user.emacs_buffer_select(emacs_buffers)
  edit.file_end()
switch {user.emacs_buffers} go <number>:
  user.emacs_buffer_select(emacs_buffers)
  edit.jump_line(number)

other switch {user.emacs_buffers} [go] top:
  user.emacs_buffer_select_other(emacs_buffers)
  edit.file_start()
other switch {user.emacs_buffers} search:
  user.emacs_buffer_select_other(emacs_buffers)
  edit.file_start()
  edit.find()
other switch {user.emacs_buffers} [go] bottom:
  user.emacs_buffer_select_other(emacs_buffers)
  edit.file_end()
other switch {user.emacs_buffers} go <number>:
  user.emacs_buffer_select_other(emacs_buffers)
  edit.jump_line(number)

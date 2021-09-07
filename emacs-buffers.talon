# switch {user.emacs_buffers} [over]: user.emacs_buffer_select(emacs_buffers)
# other switch {user.emacs_buffers} [over]: user.emacs_buffer_select_other(emacs_buffers)

switch {user.emacs_buffers}$: user.emacs_buffer_select(emacs_buffers)
switch {user.emacs_buffers} over: user.emacs_buffer_select(emacs_buffers)
other switch {user.emacs_buffers}$: user.emacs_buffer_select_other(emacs_buffers)
other switch {user.emacs_buffers} over: user.emacs_buffer_select_other(emacs_buffers)

emacs open {user.emacs_buffers}$: user.emacs_open_buffer(emacs_buffers)

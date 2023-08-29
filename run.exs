# I sort of doubt this is a typical way of doing it but I just didn't want
# to have to enter into an iex session every time I wanted to run the code.
# Plus, this lets us pass in arguments (if you try and pass in args with
# just "mix run" then only the first argument gets passed, for some reason).
HTTPComparer.Application.main(Enum.at(System.argv(), 0), Enum.at(System.argv(), 1), Enum.at(System.argv(), 2))

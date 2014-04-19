require 'pry'
class FunWithProcs
  def proc_generator
    return ->(arg) { self.send(:print, arg) }
  end

  def print(arg)
    arg.upcase
  end
end


procs = FunWithProcs.new

binding.pry
procs.proc_generator

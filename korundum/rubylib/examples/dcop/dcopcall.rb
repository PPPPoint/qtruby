#!/usr/bin/env ruby

require 'Korundum'
include KDE

class SenderWidget < PushButton
	def initialize(parent, name)
		super
		connect(self, SIGNAL('clicked()'), self, SLOT('doit()'))
	end
	
	slots 'doit()'
	
	def doit()
		puts "In doit.."
		dcopRef = DCOPRef.new("dcopslot", "MyWidget")
		result = dcopRef.call("QPoint getPoint(QString)", "Hello from dcopcall")
		puts "result class: #{result.class.name} x: #{result.x} y: #{result.y}"
	end
end

about = AboutData.new("dcopcall", "DCOP Call Test", "0.1")
CmdLineArgs.init(ARGV, about)
a = UniqueApplication.new
calltest = SenderWidget.new(nil, "calltest") { setText 'DCOP Call Test' }
a.mainWidget = calltest
calltest.show
a.exec
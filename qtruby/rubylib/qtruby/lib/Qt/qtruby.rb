=begin
/***************************************************************************
                          qtruby.rb  -  description
                             -------------------
    begin                : Fri Jul 4 2003
    copyright            : (C) 2003 by Richard Dale
    email                : Richard_Dale@tipitina.demon.co.uk
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
=end

require 'pp'

module Qt
        module DebugLevel
                Off, Minimal, High, Extensive = 0, 1, 2, 3
        end

	module QtDebugChannel 
		QTDB_NONE = 0x00
		QTDB_AMBIGUOUS = 0x01
		QTDB_METHOD_MISSING = 0x02
		QTDB_CALLS = 0x04
		QTDB_GC = 0x08
		QTDB_VIRTUAL = 0x10
		QTDB_VERBOSE = 0x20
                QTDB_ALL = QTDB_VERBOSE | QTDB_VIRTUAL | QTDB_GC | QTDB_CALLS | QTDB_METHOD_MISSING | QTDB_AMBIGUOUS
	end

        @@debug_level = DebugLevel::Off
        def Qt.debug_level=(level)
                @@debug_level = level
                Internal::setDebug Qt::QtDebugChannel::QTDB_ALL if level >= DebugLevel::Extensive
        end
        def Qt.debug_level
                @@debug_level
        end
		
	class Base
		def **(a)
			return Qt::**(self, a)
		end
		def +(a)
			return Qt::+(self, a)
		end
		def ~(a)
			return Qt::~(self, a)
		end
		def -@()
			return Qt::-(self)
		end
		def -(a)
			return Qt::-(self, a)
		end
		def *(a)
			return Qt::*(self, a)
		end
		def /(a)
			return Qt::/(self, a)
		end
		def %(a)
			return Qt::%(self, a)
		end
		def >>(a)
			return Qt::>>(self, a)
		end
		def <<(a)
			return Qt::<<(self, a)
		end
		def &(a)
			return Qt::&(self, a)
		end
		def ^(a)
			return Qt::^(self, a)
		end
		def |(a)
			return Qt::|(self, a)
		end
		def <(a)
			return Qt::<(self, a)
		end
		def <=(a)
			return Qt::<=(self, a)
		end
		def >(a)
			return Qt::>(self, a)
		end
		def >=(a)
			return Qt::>=(self, a)
		end
#		Object has a unary equality operator, so this call gives a wrong number
#		of arguments error, rather than despatched to method_missing()
#		def ==(a)
#			return Qt::==(self, a)
#		end
	end
			
	require 'delegate.rb'
	
	# Allows a QByteArray to be wrapped in an instance which
	# behaves just like a normal ruby String. TODO: override
	# methods which alter the underlying string, in order to
	# sync the QByteArray with the changed string.
	# If the data arg is nil, the string is returned as the
	# value instead. 
	class ByteArray < DelegateClass(String)
		attr_reader :private_data
		attr_reader :data
		
		def initialize(string, data=nil)
			super(string)
			@private_data = data
			@data = string
		end
	end
	
	# Delete the underlying C++ instance after exec returns
	# Otherwise, rb_gc_call_finalizer_at_exit() can delete
	# stuff that Qt::Application still needs for its cleanup.
	class Application < Qt::Base
		def exec
			super
			self.dispose
			Qt::Internal.application_terminated = true
		end
	end
	
	class Color < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " %s>" % name)
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, " %s>" % name)
		end
	end
	
	class Connection < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " memberName=%s, memberType=%s, object=%s>" %
				[memberName.inspect, memberType == 1 ? "SLOT" : "SIGNAL", object.inspect] )
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n memberName=%s,\n memberType=%s,\n object=%s>" %
				[memberName.inspect, memberType == 1 ? "SLOT" : "SIGNAL", object.inspect] )
		end
	end
	
	class Cursor < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " shape=%d>" % shape)
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, " shape=%d>" % shape)
		end
	end
	
	class Font < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " family=%s, pointSize=%d, weight=%d, italic=%s, bold=%s, underline=%s, strikeOut=%s>" % 
			[family.inspect, pointSize, weight, italic, bold, underline, strikeOut])
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n family=%s,\n pointSize=%d,\n weight=%d,\n italic=%s,\n bold=%s,\n underline=%s,\n strikeOut=%s>" % 
			[family.inspect, pointSize, weight, italic, bold, underline, strikeOut])
		end
	end
	
	class Point < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " x=%d, y=%d>" % [x, y])
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n x=%d,\n y=%d>" % [x, y])
		end
	end
	
	class MetaObject < Qt::Base
		def inspect
			str = super
			str.sub!(/>$/, "")
			str << " className=%s," % className
			str << " signalNames=Array (%d element(s))," % numSignals unless numSignals == 0
			str << " slotNames=Array (%d element(s))," % numSlots unless numSlots == 0
			str << " superClass=%s," % superClass.inspect unless superClass == nil
			str.chop!
			str << ">"
		end
		
		def pretty_print(pp)
			str = to_s
			str.sub!(/>$/, "")
			str << "\n className=%s," % className
			str << "\n signalNames=Array (%d element(s))," % numSignals unless numSignals == 0
			str << "\n slotNames=Array (%d element(s))," % numSlots unless numSlots == 0
			str << "\n superClass=%s," % superClass.inspect unless superClass == nil
			str.chop!
			str << ">"
			pp.text str
		end
	end
	
	class Rect < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " left=%d, right=%d, top=%d, bottom=%d>" % [left, right, top, bottom])
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n left=%d,\n right=%d,\n top=%d,\n bottom=%d>" % [left, right, top, bottom])
		end
	end
	
	class Size < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " width=%d, height=%d>" % [width, height])
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n width=%d,\n height=%d>" % [width, height])
		end
	end
	
	class SizePolicy < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " horData=%d, verData=%d>" % [horData, verData])
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, "\n horData=%d,\n verData=%d>" % [horData, verData])
		end
	end
	
	class Date < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " %s>" % toString)
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, " %s>" % toString)
		end
	end
	
	class DateTime < Qt::Base
		def inspect
			str = super
			str.sub(/>$/, " %s>" % toString)
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, " %s>" % toString)
		end
	end
	
	class Time < Qt::Base
		class << Qt::Time
			# This works round an incompatibility problem between QtRuby
			# and the 'require time' statement - cause unknown :(
			def now
				::Time.now
			end
			
			def local(year, mon, day, hour, min, sec)
				::Time.local(year, mon, day, hour, min, sec)
			end
			
			def utc(year, mon, day, hour, min, sec)
				::Time.utc(year, mon, day, hour, min, sec)
			end
		end
		
		def inspect
			str = super
			str.sub(/>$/, " %s>" % toString)
		end
		
		def pretty_print(pp)
			str = to_s
			pp.text str.sub(/>$/, " %s>" % toString)
		end
	end
	
	# Provides a mutable numeric class for passing to methods with
	# C++ 'int*' or 'int&' arg types
	class Integer
		attr_accessor :value
		def initialize(n=0) @value = n end
		
		def +(n) 
			return Integer.new(@value + n.to_i) 
		end
		def -(n) 
			return Integer.new(@value - n.to_i)
		end
		def *(n) 
			return Integer.new(@value * n.to_i)
		end
		def /(n) 
			return Integer.new(@value / n.to_i)
		end
		def %(n) 
			return Integer.new(@value % n.to_i)
		end
		def **(n) 
			return Integer.new(@value ** n.to_i)
		end
		
		def |(n) 
			return Integer.new(@value | n.to_i)
		end
		def &(n) 
			return Integer.new(@value & n.to_i)
		end
		def ^(n) 
			return Integer.new(@value ^ n.to_i)
		end
		def <<(n) 
			return Integer.new(@value << n.to_i)
		end
		def >>(n) 
			return Integer.new(@value >> n.to_i)
		end
		
		def <=>(n)
			if @value < n
				return -1
			elsif @value > n
				return 1
			else
				return 0
			end
		end
		
		def to_f() return @value.to_f end
		def to_i() return @value.to_i end
		def to_s() return @value.to_s end
		
		def coerce(n)
			[n, @value]
		end
	end
	
	# If a C++ enum was converted to an ordinary ruby Integer, the
	# name of the type is lost. The enum type name is needed for overloaded
	# method resolution when two methods differ only by an enum type.
	class Enum < Qt::Integer
		attr_accessor :type
		def initialize(n, type)
			super(n) 
			@value = n 
			@type = type
		end
		
		def |(n) 
			return Enum.new(@value | n.to_i, @type)
		end
		def &(n) 
			return Enum.new(@value & n.to_i, @type)
		end
		def ^(n) 
			return Enum.new(@value ^ n.to_i, @type)
		end
		def <(n) 
			return @value < n.to_i
		end
		def <=(n) 
			return @value <= n.to_i
		end
		def >(n) 
			return @value > n.to_i
		end
		def >=(n) 
			return @value >= n.to_i
		end
		def <<(n) 
			return Enum.new(@value << n.to_i, @type)
		end
		def >>(n) 
			return Enum.new(@value >> n.to_i, @type)
		end
		
		def ==(n) return @value == n.to_i end
		def to_i() return @value end
	end
	
	# Provides a mutable boolean class for passing to methods with
	# C++ 'bool*' or 'bool&' arg types
	class Boolean
		attr_accessor :value
		def initialize(b=false) @value = b end
		def nil? 
			return !@value 
		end
	end
	
	module Internal

		@@classes   = {}
		@@cpp_names = {}
		@@idclass   = []

		def normalize_classname(classname)
			if classname =~ /^Q/
				now = classname.sub(/^Q(?=[A-Z])/,'Qt::')
			elsif classname =~ /^(KConfigSkeleton|KWin)::/
				now = classname.sub(/^K?(?=[A-Z])/,'KDE::')
			elsif classname !~ /::/
				now = classname.sub(/^K?(?=[A-Z])/,'KDE::')
			else
				now = classname
			end
			# puts "normalize_classname = was::#{classname}, now::#{now}"
			now
		end

		def init_class(c)
			classname = normalize_classname(c)
			classId = idClass(c)
			insert_pclassid(classname, classId)
			@@idclass[classId] = classname
			@@cpp_names[classname] = c
			klass = isQObject(classId) ? create_qobject_class(classname) \
                                                   : create_qt_class(classname)
			@@classes[classname] = klass unless klass.nil?
		end

                def debug_level
                        Qt.debug_level
                end

		def checkarg(argtype, typename)
			puts "      #{typename} (#{argtype})" if debug_level >= DebugLevel::High
			if argtype == 'i'
				if typename =~ /^int&?$|^signed$/
					return 1
				elsif typename =~ /^(?:short|ushort|uint|long|ulong|unsigned|float|double)$/
					return 0
				else 
					t = typename.sub(/^const\s+/, '')
					t.sub!(/[&*]$/, '')
					if isEnum(t)
						return 0
					end
				end
			elsif argtype == 'n'
				if typename =~ /^double$/
					return 2
				elsif typename =~ /^float$/
					return 1
				elsif typename =~ /^int&?$/
					return 0
				elsif typename =~ /^(?:short|ushort|uint|long|ulong|signed|unsigned|float|double)$/
					return 0
				else 
					t = typename.sub(/^const\s+/, '')
					t.sub!(/[&*]$/, '')
					if isEnum(t)
						return 0
					end
				end
			elsif argtype == 'B'
				if typename =~ /^(?:bool)[*&]?$/
					return 0
				end
			elsif argtype == 'b'
				# An argtype 'b' means a Qt::ByteArray has been passed to a C++ method expecting a QByteArray arg.
				# In that case a Qt::ByteArray must take precedence over any String, and scores 3. Note that a
				# ruby String would only score 2 when passed to the same QByteArray method - an alternative 
				# method expecting a QString arg would take precedence over it with a score of 3.
				if typename =~ /^(const )?(QByteArray[*&]?)$/
					return 3
				end
			elsif argtype == 's'
				if typename =~ /^(const )?((QByteArray|QChar)[*&]?)$/
					return 1
				elsif typename =~ /^(?:u?char\*|const u?char\*|(?:const )?(Q(C?)String)[*&]?)$/
					qstring = !$1.nil?
					c = ("C" == $2)
					return c ? 2 : (qstring ? 3 : 0)
				end
			elsif argtype == 'a'
				# FIXME: shouldn't be hardcoded. Installed handlers should tell what ruby type they expect.
				if typename =~ /^(?:
						const\ QCOORD\*|
						(?:const\ )?
						(?:
						    QStringList[\*&]?|
						    QValueList<int>[\*&]?|
						    QRgb\*|
						    char\*\*
						)
					        )$/x
					return 0
				end
			elsif argtype == 'u'
				# Give nil matched against string types a higher score than anything else
				if typename =~ /^(?:u?char\*|const u?char\*|(?:const )?((Q(C?)String)|QByteArray)[*&]?)$/
					return 1
				# Numerics will give a runtime conversion error, so they fail the match
				elsif typename =~ /^(?:short|ushort|uint|long|ulong|signed|unsigned|int)$/
					return -99
				else
					return 0
				end
			elsif argtype == 'U'
				if typename =~ /QStringList/
					return 1
				else
					return 0
				end
			else
				t = typename.sub(/^const\s+/, '')
				t.sub!(/[&*]$/, '')
				if argtype == t
					return 1
				elsif classIsa(argtype, t)
					return 0
				elsif isEnum(argtype) and 
						(t =~ /int|uint|long|ulong|WFlags|WState|ProcessEventsFlags|ComparisonFlags/ or
						t =~ /SFlags|SCFlags|WId|difference_type|ToolBarDock/ or
						t =~ /KStyleFlags|KonqPopupFlags/)
					return 0
				end
			end
			return -99
		end

		def find_class(classname)
			# puts @@classes.keys.sort.join "\n"
			@@classes[classname]
		end
		
		# Runs the initializer as far as allocating the Qt C++ instance.
		# Then use a throw to jump back to here with the C++ instance 
		# wrapped in a new ruby variable of type T_DATA
		def try_initialize(instance, *args)
			# If a debugger calls an inspect method with the half 
			# constructed instance, it will fail. So prevent that by
			# defining a dummy 'do nothing' inspect method here
			class <<instance
				def inspect
					return nil
				end
				def pretty_print(pp)
					return nil
				end
			end
			
			initializer = instance.method(:initialize)
			catch "newqt" do 
				initializer.call(*args)
			end
		end
		
        # If a block was passed to the constructor, then
		# run that now. Either run the context of the new instance
		# if no args were passed to the block. Or otherwise,
		# run the block in the context of the arg.
		def run_initializer_block(instance, block)
			if block.arity == -1
				instance.instance_eval(&block)
			elsif block.arity == 1
				block.call(instance)
			else
				raise ArgumentError, "Wrong number of arguments to block(#{block.arity} for 1)"
			end
		end

		def do_method_missing(package, method, klass, this, *args)
			if klass.class == Module
				classname = klass.name
			else
				classname = @@cpp_names[klass.name]
				if classname.nil?
					if klass != Object and klass != KDE and klass != Qt
						return do_method_missing(package, method, klass.superclass, this, *args)
					else
						return nil
					end
				end
			end
			
			if method == "new"
				method = classname.dup 
				method.gsub!(/^(KParts|KIO|KNS|khtml|DOM|Kontact|Kate|KTextEditor|KConfigSkeleton::ItemEnum|KConfigSkeleton|KWin)::/,"")
			end
			method = "operator" + method.sub("@","") if method !~ /[a-zA-Z]+/
			# Change foobar= to setFoobar()					
			method = 'set' + method[0,1].upcase + method[1,method.length].sub("=", "") if method =~ /.*[^-+%\/|]=$/

			methods = []
			methods << method.dup
			args.each do |arg|
				if arg.nil?
					# For each nil arg encountered, triple the number of munged method
					# templates, in order to cover all possible types that can match nil
					temp = []
					methods.collect! do |meth| 
						temp << meth + '?' 
						temp << meth + '#'
						meth << '$'
					end
					methods.concat(temp)
				elsif isObject(arg)
					methods.collect! { |meth| meth << '#' }
				elsif arg.kind_of? Array or arg.kind_of? Hash
					methods.collect! { |meth| meth << '?' }
				else
					methods.collect! { |meth| meth << '$' }
				end
			end
			
			methodIds = []
			methods.collect { |meth| methodIds.concat( findMethod(classname, meth) ) }
			
			if method =~ /_/ && methodIds.length == 0
				# If the method name contains underscores, convert to camel case
				# form and try again
				while method =~ /([^_]*)_(.)(.*)/ 
					method = $1 + $2.upcase + $3
				end
				return do_method_missing(package, method, klass, this, *args)
			end

			if debug_level >= DebugLevel::High
				puts "classname    == #{classname}"
				puts ":: method == #{method}"
				puts "-> methodIds == #{methodIds.inspect}"
				puts "candidate list:"
				prototypes = dumpCandidates(methodIds).split("\n")
				line_len = (prototypes.collect { |p| p.length }).max
				prototypes.zip(methodIds) { 
					|prototype,id| puts "#{prototype.ljust line_len}  (#{id})" 
				}
			end
			
			chosen = nil
			if methodIds.length > 0
				best_match = -1
				methodIds.each do
					|id|
					puts "matching => #{id}" if debug_level >= DebugLevel::High
					current_match = 0
					(0...args.length).each do
						|i|
						current_match += checkarg( getVALUEtype(args[i]), getTypeNameOfArg(id, i) )
					end
					
					# Note that if current_match > best_match, then chosen must be nil
					if current_match > best_match
						best_match = current_match
						chosen = id
					# Multiple matches are an error; the equality test below _cannot_ be commented out.
					# If ambiguous matches occur the problem must be fixed be adjusting the relative
					# ranking of the arg types involved in checkarg().
					elsif current_match == best_match
						chosen = nil
					end
					puts "match => #{id} score: #{current_match}" if debug_level >= DebugLevel::High
				end
					
				puts "Resolved to id: #{chosen}" if !chosen.nil? && debug_level >= DebugLevel::High
			end

			if debug_level >= DebugLevel::Minimal && chosen.nil? && method !~ /^operator/
				id = find_pclassid(normalize_classname(klass.name))
				hash = findAllMethods(id)
				constructor_names = nil
				if method == classname
					puts "No matching constructor found, possibles:\n"
					constructor_names = hash.keys.grep(/^#{classname}/)
				else
					puts "Possible prototypes:"
					constructor_names = hash.keys
				end
				method_ids = hash.values_at(*constructor_names).flatten
				puts dumpCandidates(method_ids)
			end

			puts "setCurrentMethod(#{chosen})" if debug_level >= DebugLevel::High
			setCurrentMethod(chosen) if chosen
			return nil
		end

		def init_all_classes()
			getClassList().each {
                                |c|
				if c == "Qt"
					# Don't change Qt to Qt::t, just leave as is
					@@cpp_names["Qt"] = c
				elsif c != "QInternal"
					init_class(c)
				end
                        }
			# Special case QByteArray, as it's disguised as a ruby String
			# and not in the public api.
			@@classes['Qt::ByteArray'] = Qt::ByteArray.class
			@@classes['Qt::Integer'] = Qt::Integer.class
			@@classes['Qt::Boolean'] = Qt::Boolean.class
			@@classes['Qt::Enum'] = Qt::Enum.class
		end
		
		def create_qbytearray(string, data)
			return Qt::ByteArray.new(string, data)
		end
		
		def get_qbytearray(str)
			if str.private_data.nil?
				return str.data
			end
			return str.private_data
		end
		
		def get_qinteger(num)
			return num.value
		end
		
		def set_qinteger(num, val)
			return num.value = val
		end
		
		def create_qenum(num, type)
			return Qt::Enum.new(num, type)
		end
		
		def get_qenum_type(e)
			return e.type
		end
		
		def get_qboolean(b)
			return b.value
		end
		
		def set_qboolean(b, val)
			return b.value = val
		end
	end

	Meta = {}
	
	# An entry for each signal or slot
	# Example 
	#  foobar(QString,bool)
	#  :name is 'foobar'
	#  :full_name is 'foobar(QString,bool)'
	#  :arg_types is 'QString,bool'
	QObjectMember = Struct.new :name, :full_name, :arg_types

	class MetaInfo
		attr_accessor :signals, :slots, :metaobject, :mocargs, :changed
		def initialize(aClass)
			Meta[aClass.name] = self
			@klass = aClass
			@metaobject = nil
			@signals = []
			@slots = []
			@changed = false
		end
		
		def add_signals(signal_list)
			signal_list.each do |signal|
				signal = Qt::Object.normalizeSignalSlot(signal)
				if signal =~ /([^\s]*)\((.*)\)/
					@signals.push QObjectMember.new($1, signal, $2)
				else
					qWarning( "#{@klass.name}: Invalid signal format: '#{signal}'" )
				end
			end
		end
		
		# Return a list of signals, including inherited ones
		def get_signals
			all_signals = []
			current = @klass
			while current != Qt::Base
				meta = Meta[current.name]
				if !meta.nil?
					all_signals.concat meta.signals
				end
				current = current.superclass
			end
			return all_signals
		end
		
		def add_slots(slot_list)
			slot_list.each do |slot|
				slot = Qt::Object.normalizeSignalSlot(slot)
				if slot =~ /([^\s]*)\((.*)\)/
					@slots.push QObjectMember.new($1, slot, $2)
				else
					qWarning( "#{@klass.name}: Invalid slot format: '#{slot}'" )
				end
			end
		end
		
		# Return a list of slots, including inherited ones
		def get_slots
			all_slots = []
			current = @klass
			while current != Qt::Base
				meta = Meta[current.name]
				if !meta.nil?
					all_slots.concat meta.slots
				end
				current = current.superclass
			end
			return all_slots
		end
	end

	def getAllParents(class_id, res)
		getIsa(class_id).each {
			|s|
			c = idClass(s)
			res << c
			getAllParents(c, res)
		}
	end

	def getSignalNames(klass)
		meta = Meta[klass.name] || MetaInfo.new(klass)
		signal_names = []
		meta.get_signals.each do |signal|
			signal_names.push signal.name
		end
		return signal_names 
	end

	def signalInfo(qobject, signal_name)
		signals = Meta[qobject.class.name].get_signals
                signals.each_with_index {
                        |signal, i|
                        if signal.name == signal_name
                        	return [signal.full_name, i]
                        end
                }
	end

	def signalAt(qobject, index)
		classname = qobject.class.name
		Meta[classname].get_signals[index].full_name
	end

	def slotAt(qobject, index)
		classname = qobject.class.name
		Meta[classname].get_slots[index].full_name
	end

	def getMocArguments(member)
		argStr = member.sub(/.*\(/, '').sub(/\)$/, '')
		args = argStr.scan(/([^,]*<[^>]+>)|([^,]+)/)
		mocargs = allocateMocArguments(args.length)
                args.each_with_index {
                        |arg, i|
			arg = arg.to_s
			a = arg.sub(/^const\s+/, '')
			a = (a =~ /^(bool|int|double|char\*|QString)&?$/) ? $1 : 'ptr'
			valid = setMocType(mocargs, i, arg, a)
                }
		result = []
		result << args.length << mocargs
		result
	end

	def makeMetaData(data)
		return nil if data.nil?
		tbl = []
		data.each {
			|entry|
			name = entry.name
			argStr = entry.arg_types
			params = []
			args = argStr.scan(/[^,]+/)
			args.each {
				|arg|
				name = '' # umm.. is this the aim?, well. it works. soo... ;-)
				param = make_QUParameter(name, arg, 0, 1)
                                params << param
			}
			method = make_QUMethod(name, params)
			tbl << make_QMetaData(entry.full_name, method)
		}
		make_QMetaData_tbl(tbl)
	end
	
	def getMetaObject(qobject)
		meta = Meta[qobject.class.name]
		return nil if meta.nil?

		if meta.metaobject.nil? or meta.changed
			slots 			= meta.get_slots
			slotTable       = makeMetaData(slots)
			signals 		= meta.get_signals
			signalTable     = makeMetaData(signals)
			meta.metaobject = make_metaObject(qobject.class.name, 
			                                  qobject.staticMetaObject(),
			                                  slotTable, 
			                                  slots.length,
			                                  signalTable, 
			                                  signals.length)
			meta.changed = false
		end
		
		meta.metaobject
	end

	IO_Direct     = 0x0100
	IO_Sequential = 0x0200
	IO_Combined   = 0x0300
	IO_TypeMask   = 0x0f00
	IO_Raw        = 0x0040
	IO_Async      = 0x0080
	IO_ReadOnly   = 0x0001
	IO_WriteOnly  = 0x0002
	IO_ReadWrite  = 0x0003
	IO_Append     = 0x0004
	IO_Truncate   = 0x0008
	IO_Translate  = 0x0010
	IO_ModeMask   = 0x00ff
	IO_Open       = 0x1000
	IO_StateMask  = 0xf000
	IO_Ok              = 0
	IO_ReadError       = 1
	IO_WriteError      = 2
	IO_FatalError      = 3
	IO_ResourceError   = 4       
	IO_OpenError       = 5
	IO_ConnectError    = 5
	IO_AbortError      = 6
	IO_TimeOutError    = 7
	IO_UnspecifiedError= 8
		
end

class Object
	# The Object.display() method conflicts with display() methods in Qt,
	# so remove it, and other methods with similar problems
	alias_method :_display, :display
	undef_method :display
	
	alias_method :_type, :type
	undef_method :type
	
	def SIGNAL(string) ; return "2" + string; end
	def SLOT(string)   ; return "1" + string; end
	def emit(signal)   ; end
end

module Kernel
	alias_method :_exec, :exec
	undef_method :exec
	
	# Kernel has a method called open() which takes a String as
	# the first argument. When a call is made to an open() method
	# in the Qt classes, it messes up the method_missing()
	# logic to divert it to the Smoke library. This code
	# fixes that problem by calling the appropriate method based
	# on the type of the first arg.
	alias_method :_open, :open
	
	def open(*k)
		if k.length > 0 and k[0].kind_of? String
			_open(*k)
		else
			method_missing(:open, *k)
		end
	end
end

class Module
	include Qt

	def signals(*signal_list)
		meta = Meta[self.name] || MetaInfo.new(self)
		meta.add_signals(signal_list)
		meta.changed = true
	end

	def slots(*slot_list)
		meta = Meta[self.name] || MetaInfo.new(self)
		meta.add_slots(slot_list)
		meta.changed = true
	end
end

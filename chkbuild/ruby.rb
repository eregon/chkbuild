# chkbuild/ruby.rb - ruby build module
#
# Copyright (C) 2006-2012 Tanaka Akira  <akr@fsij.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice, this
#     list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#  3. The name of the author may not be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.

require 'chkbuild'

module ChkBuild::Ruby
  METHOD_LIST_SCRIPT = <<'End'
use_symbol = Object.instance_methods[0].is_a?(Symbol)
nummodule = nummethod = 0
mods = []
ObjectSpace.each_object(Module) {|m| mods << m if m.name }
mods = mods.sort_by {|m| m.name }
mods.each {|mod|
  nummodule += 1
  puts "#{mod.name} #{(mod.ancestors - [mod]).inspect}"
  mod.singleton_methods(false).sort.each {|methname|
    nummethod += 1
    meth = mod.method(methname)
    line = "#{mod.name}.#{methname} #{meth.arity}"
    line << " not-implemented" if !mod.respond_to?(methname)
    puts line
  }
  ms = mod.instance_methods(false)
  if use_symbol
    ms << :initialize if mod.private_instance_methods(false).include? :initialize
  else
    ms << "initialize" if mod.private_instance_methods(false).include? "initialize"
  end
  ms.sort.each {|methname|
    nummethod += 1
    meth = mod.instance_method(methname)
    line = "#{mod.name}\##{methname} #{meth.arity}"
    line << " not-implemented" if /\(not-implemented\)/ =~ meth.inspect
    puts line
  }
}
puts "#{nummodule} modules, #{nummethod} methods"
End

  VERSION_LIST_SCRIPT = <<'End'
  [
    ["dbm", lambda { DBM::VERSION }],
    ["gdbm", lambda { GDBM::VERSION }],
    ["readline", lambda { Readline::VERSION }],
    ["openssl", lambda { OpenSSL::OPENSSL_VERSION }],
    ["zlib", lambda { hv = Zlib::ZLIB_VERSION; lv = Zlib.zlib_version; lv == hv ? lv : "header:#{hv} library:#{lv}" }],
    ["tcltklib", lambda { TclTkLib::COMPILE_INFO }],
    ["curses", lambda { Curses::VERSION }],
  ].each {|feature, versionproc|
    begin
      require feature
      puts "#{feature}: #{versionproc.call}"
    rescue Exception
      puts "#{feature}: #{$!}"
    end
  }
End

  # not strictly RFC 1034.
  DOMAINLABEL = /[A-Za-z0-9-]+/
  DOMAINPAT = /#{DOMAINLABEL}(\.#{DOMAINLABEL})*/

  MaintainedBranches = %w[trunk 2.0.0 1.9.3 1.9.2 1.8 1.8.7]

  module_function

  def def_target(*args)
    args << { :complete_options => CompleteOptions }
    ChkBuild.def_target("ruby", *args)
  end

  def count_prefix(pat, str)
    n = 0
    str.scan(pat) { n += 1 }
    case n
    when 0
      nil
    when 1
      ""
    else
      n.to_s
    end
  end

  def rubyspec_exclude_directories(excludes = ["rubyspec/optional/ffi"], args = ["rubyspec"])
    excludes = excludes.map {|f| File.directory?(f) ? "#{f}/" : f }
    args = args.map {|f| File.directory?(f) ? "#{f}/" : f }
    while !excludes.empty?
      args = args.map {|arg|
	if %r{/\z} =~ arg && excludes.any? {|e| e.start_with?(arg) }
	  Dir["#{arg}*"].sort.map {|n|
	    if %w[.git fixtures nbproject shared tags].include? File.basename(n)
	      []
	    elsif File.directory?(n)
	      "#{n}/"
	    elsif /_spec\.rb\z/ =~ n
	      n
	    else
	      []
	    end
	  }
	else
	  arg
	end
      }
      args.flatten!
      matched = args & excludes
      args -= matched
      excludes -= matched
    end
    args = args.map {|arg| arg.chomp("/") }
    args
  end
end

module ChkBuild::Ruby::CompleteOptions
end

def (ChkBuild::Ruby::CompleteOptions).call(target_opts)
  hs = []
  suffixes = Util.opts2funsuffixes(target_opts)
  suffixes.each {|s|
    case s
    when "trunk" then hs << { :ruby_branch => 'trunk' }
    when "mvm" then hs << { :ruby_branch => 'branches/mvm' }
    when "half-baked-1.9" then hs << { :ruby_branch => 'branches/half-baked-1.9' }
    when "matzruby" then hs << { :ruby_branch => 'branches/matzruby' }
    when "2.0.0" then hs << { :ruby_branch => 'branches/ruby_2_0_0' }
    when "1.9.3" then hs << { :ruby_branch => 'branches/ruby_1_9_3' }
    when "1.9.2" then hs << { :ruby_branch => 'branches/ruby_1_9_2' }
    when "1.9.1" then hs << { :ruby_branch => 'branches/ruby_1_9_1' }
    when "1.8" then hs << { :ruby_branch => 'branches/ruby_1_8' }
    when "1.8.7" then hs << { :ruby_branch => 'branches/ruby_1_8_7' }
    when "1.8.6" then hs << { :ruby_branch => 'branches/ruby_1_8_6' }
    when "1.8.5" then hs << { :ruby_branch => 'branches/ruby_1_8_5' }
    when "o0" then hs << { :optflags => %w[-O0] }
    when "o1" then hs << { :optflags => %w[-O1] }
    when "o2" then hs << { :optflags => %w[-O2] }
    when "o3" then hs << { :optflags => %w[-O3] }
    when "os" then hs << { :optflags => %w[-Os] }
    when "pth" then hs << { :configure_args_pthread => %w[--enable-pthread] }
    when "m32" then hs << { :cflags => ['-m32'], :dldflags => ['-m32'] }
    when "m64" then hs << { :cflags => ['-m64'], :dldflags => ['-m64'] }
    else
      raise "unexpected suffix: #{s.inspect}"
    end
  }

  if target_opts["--with-opt-dir"]
    v = target_opts["--with-opt-dir"]
    hs << { :configure_args_with_opt_dir => ["--with-opt-dir=#{v}"] }
  end

  if Util.search_command('git')
    hs << { :use_rubyspec => true }
  end

  hs << {
    :autoconf_command => 'autoconf',
    :configure_args => [],
    :configure_args_valgrind => %w[--with-valgrind],
    :cflags => [],
    :cppflags => %w[-DRUBY_DEBUG_ENV],
    :optflags => %w[-O2],
    :debugflags => %w[-g],
    :warnflags => %w[-W -Wall -Wformat=2 -Wundef -Wno-parentheses -Wno-unused-parameter -Wno-missing-field-initializers],
    :dldflags => %w[],
    :make_options => {},
    :force_gperf => false,
    :use_rubyspec => false,
    :inplace_build => true,
    :validate_dependencies => false,
  }

  opts = target_opts.dup
  hs.each {|h|
    h.each {|k, v|
      opts[k] = v if !opts.include?(k)
    }
  }

  ruby_branch = opts.fetch(:ruby_branch)

  if /ruby_1_9_1/ =~ ruby_branch && opts[:use_rubyspec]
    opts[:use_rubyspec] = false
  end

  if ruby_branch == 'branches/mvm' &&
     opts.fetch(:cppflags, []).include?('-DRUBY_DEBUG_ENV')
    opts.fetch(:cppflags).delete '-DRUBY_DEBUG_ENV'
  end

  if Util.opts2aryparam(opts, :configure_args).include?("--enable-pthread")
    if %r{\Abranches/ruby_1_8} !~ ruby_branch &&
       %r{\Abranches/matzruby} !~ ruby_branch
      return nil
    end
  end

  if ruby_branch != "trunk"
    opts[:validate_dependencies] = false
  end

  opts
end

def (ChkBuild::Ruby::CompleteOptions).merge_dependencies(opts, dep_dirs)
  opts = opts.dup
  hs = []
  dep_dirs.each {|s|
    case s
    when /\Agcc=/ then
      hs << { :configure_args_cc => "CC=#{$'}/bin/gcc",
	      :"make_options_ENV:LD_RUN_PATH" => "#{$'}/lib" }
    when /\Aautoconf=/ then
      hs << { :autoconf_command => "#{$'}/bin/autoconf" }
    when /\Aopenssl=/
      hs << { :configure_args_openssl => "--with-openssl-dir=#{$'}" }
      hs << { :configure_args_digest => "--with-digest-dir=#{$'}" }
    when /\Agdbm=/
      hs << { :configure_args_gdbm => "--with-gdbm-dir=#{$'}" }
      hs << { :configure_args_dbm => "--with-dbm-dir=#{$'}" }
    when /\Azlib=/
      hs << { :configure_args_zlib => "--with-zlib-dir=#{$'}" }
    when /\Alibffi=/
      hs << { :configure_args_fiddle => "--with-libffi-dir=#{$'}" }
    end
  }
  hs.each {|h|
    opts.update h
  }
  #pp opts
  opts
end

ChkBuild.define_build_proc('ruby') {|b|
  bopts = b.opts
  ruby_branch = bopts[:ruby_branch]
  configure_args = Util.opts2aryparam(bopts, :configure_args)
  cflags = Util.opts2aryparam(bopts, :cflags)
  cppflags = Util.opts2aryparam(bopts, :cppflags)
  optflags = Util.opts2aryparam(bopts, :optflags)
  debugflags = Util.opts2aryparam(bopts, :debugflags)
  warnflags = Util.opts2aryparam(bopts, :warnflags)
  dldflags = Util.opts2aryparam(bopts, :dldflags)
  autoconf_command = bopts[:autoconf_command]
  make_options = Util.opts2hashparam(bopts, :make_options)
  use_rubyspec = bopts[:use_rubyspec]
  force_gperf = bopts[:force_gperf]
  inplace_build = bopts[:inplace_build]
  parallel = bopts[:parallel]
  validate_dependencies = bopts[:validate_dependencies]

  b.run(autoconf_command, '--version', :section=>'autoconf-version')
  b.run('bison', '--version', :section=>'bison-version')

  if validate_dependencies
    debugflags += %w[-save-temps=obj]
  end

  if %r{branches/ruby_1_8_} =~ ruby_branch && $' < "8"
    cflags.concat cppflags
    cflags.concat optflags
    cflags.concat debugflags
    cflags.concat warnflags
    cppflags = nil
    optflags = nil
    debugflags = nil
    warnflags = nil
  end

  ruby_build_dir = b.build_dir
  objdir = ruby_build_dir+'ruby'
  if !inplace_build
    checkout_dir = b.target_dir
  else
    checkout_dir = ruby_build_dir
  end
  srcdir = (checkout_dir+'ruby').relative_path_from(objdir)

  Dir.chdir(checkout_dir)
  b.svn("http://svn.ruby-lang.org/repos/ruby", ruby_branch, 'ruby')
  b.svn_info('ruby')
  svn_info_section = b.logfile.get_section('svn-info/ruby')
  ruby_svn_rev = svn_info_section[/Last Changed Rev: (\d+)/, 1].to_i

  Dir.chdir("ruby")

  version_data = {
    'version.h' => %w[
      RUBY_BRANCH_NAME
      RUBY_PATCHLEVEL
      RUBY_RELEASE_CODE
      RUBY_RELEASE_DATE
      RUBY_RELEASE_DAY
      RUBY_RELEASE_MONTH
      RUBY_RELEASE_YEAR
      RUBY_VERSION
      RUBY_VERSION_CODE
      RUBY_VERSION_MAJOR
      RUBY_VERSION_MINOR
      RUBY_VERSION_TEENY
    ],
  }
  if version_data.keys.any? {|fn| File.exist? fn }
    b.logfile.start_section 'version.h'
    version_data.each {|fn, version_macros|
      if File.exist? fn
        File.foreach(fn) {|line|
          if /\A\#\s*define\s+([A-Z_]+)\s+(\S.*)\n\z/ =~ line &&
             version_macros.include?($1)
            puts line
          end
        }
      end
    }
  end

  if force_gperf
    b.run('gperf', '--version', :section=>'gperf-version')
    if File.exist?('defs/lex.c.src') && File.exist?('lex.c.blt')
      b.run('rm', 'defs/lex.c.src', 'lex.c.blt', :section=>'force-gperf')
    elsif File.exist?('lex.c.src') && File.exist?('lex.c.blt')
      b.run('rm', 'lex.c.src', 'lex.c.blt', :section=>'force-gperf')
    elsif File.exist?('lex.c')
      b.run('rm', 'lex.c', :section=>'force-gperf')
    else
      b.run('echo', 'lex.c related files not found', :section=>'force-gperf')
    end
  end

  b.run(autoconf_command)

  Dir.chdir(ruby_build_dir)

  use_rubyspec &&= b.catch_error {
    opts2 = bopts.dup
    opts2[:section] = "git-mspec"
    b.git('git://github.com/nurse/mspec.git', 'mspec', opts2)
  }
  use_rubyspec &&= b.catch_error {
    opts2 = bopts.dup
    opts2[:section] = "git-rubyspec"
    b.git('git://github.com/nurse/rubyspec.git', 'rubyspec', opts2)
  }

  b.mkcd("ruby")
  args = []
  args << "--prefix=#{ruby_build_dir}"
  args << "CFLAGS=#{cflags.join(' ')}" if cflags && !cflags.empty?
  args << "CPPFLAGS=#{cppflags.join(' ')}" if cppflags && !cppflags.empty?
  args << "optflags=#{optflags.join(' ')}" if optflags
  args << "debugflags=#{debugflags.join(' ')}" if debugflags
  args << "warnflags=#{warnflags.join(' ')}" if warnflags
  args << "DLDFLAGS=#{dldflags.join(' ')}" unless dldflags.empty?
  args.concat configure_args
  b.run("#{srcdir}/configure", *args)

  verconf_list = [
    'verconf.h',
    'config.h',
    *Dir.glob(".ext/include/*/ruby/config.h")
  ]
  if verconf_list.any? {|fn| File.exist? fn }
    b.logfile.start_section 'verconf.h'
    verconf_list.each {|fn|
      if File.exist? fn
        File.foreach(fn) {|line|
          if /\A\#\s*define\s+([A-Z_]+)\s+(\S.*)\n\z/ =~ line &&
             $1 == 'RUBY_PLATFORM'
            puts line
          end
        }
      end
    }
  end

  if /^CC[ \t]*=[ \t](.*)/ =~ File.read('Makefile')
    cc = $1
    if /gcc/ =~ cc
      b.run(cc, '--version', :section=>'cc-version')
    end
  end

  make_args = ["miniruby", make_options]
  make_args.unshift "-j#{parallel}" if parallel
  b.make(*make_args)
  b.catch_error { b.run("./miniruby", "-v", :section=>"miniversion") }
  if File.directory? "#{srcdir}/bootstraptest"
    b.catch_error { b.make("btest", "OPTS=-v -q", make_options.merge(:section=>"btest")) }
  end
  b.catch_error {
    b.run("./miniruby", "#{srcdir+'sample/test.rb'}", :section=>"test.rb")
    if /^end of test/ !~ b.logfile.get_section('test.rb')
      raise ChkBuild::Build::CommandError.new(0, "test.rb")
    end
  }
  b.catch_error { b.run("./miniruby", '-e', ChkBuild::Ruby::METHOD_LIST_SCRIPT, :section=>"method-list") }

  # Ruby 1.9 provides 'main' target to build ruby excluding documents.
  makefile_lines = IO.readlines('Makefile')
  makefile_lines.concat IO.readlines('uncommon.mk') if File.file?('GNUmakefile') && File.file?('uncommon.mk')

  do_rdoc = true
  if makefile_lines.grep(/\Aall:.*\S/).sort == ["all: showflags main docs\n"]
    b.make('showflags', make_options)
    make_args = ['main', make_options]
    make_args.unshift "-j#{parallel}" if parallel
    b.make(*make_args)
    do_rdoc &&= b.catch_error {
      make_args = ['docs', make_options]
      make_args.unshift "-j#{parallel}" if parallel
      b.make(*make_args)
    }
  else
    make_args = [make_options]
    make_args.unshift "-j#{parallel}" if parallel
    b.make(*make_args)
  end

  b.catch_error {
    if File.file? "tool/runruby.rb"
      # tool/runruby.rb is required if --enable-shared because libruby.so is not installed yet.
      b.run("tool/runruby.rb", "-v", :section=>"version")
    else
      # tool/runruby.rb is not available on Ruby 1.8.
      b.run("./ruby", "-v", :section=>"version")
    end
  }
  b.make("install-nodoc", make_options)
  do_rdoc &&= b.catch_error { b.make("install-doc", make_options) }
  b.catch_error { b.run("./ruby", '-e', ChkBuild::Ruby::VERSION_LIST_SCRIPT, :section=>"version-list") }

  if validate_dependencies
    b.catch_error {
      b.make("golf")
      b.run("./ruby", "tool/update-deps", :section=>"update-deps")
    }
  end

  if File.file? "#{srcdir}/KNOWNBUGS.rb"
    b.catch_error { b.make("test-knownbug", "OPTS=-v -q", make_options) }
  end
  b.catch_error {
    parallel_option = ''
    parallel_option = "j#{parallel}" if parallel
    b.make("test-all", "TESTS=-v#{parallel_option}", "RUBYOPT=-w", make_options.merge(:section=>"test-all"))
  }
  b.catch_error {
    if /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors/ !~ b.logfile.get_section('test-all')
      ts = Dir.entries(srcdir+"test").sort
      ts.each {|t|
	next if %r{\A\.} =~ t
	s = File.lstat(srcdir+"test/#{t}")
	if s.directory? || (s.file? && /\Atest_/ =~ t)
	  b.catch_error {
	    if /\A-/ =~ t
	      testpath = srcdir+"test/#{t}" # prevent to interpret -ext- as an option
	    else
	      testpath = t # "TESTS=-v test/foo" doesn't work on Ruby 1.8
	    end
	    b.make("test-all", "TESTS=-v #{testpath}", "RUBYOPT=-w", make_options.merge(:section=>"test/#{t}"))
	  }
	end
      }
    end
  }

  Dir.chdir(ruby_build_dir)
  if use_rubyspec
    rubybin = ruby_build_dir + "bin/ruby"
    excludes = ["rubyspec/optional/ffi"]
    b.catch_error {
      FileUtils.rmtree "rubyspec_temp"
      if %r{branches/ruby_1_8} =~ ruby_branch
	config = Dir.pwd + "/rubyspec/ruby.1.8.mspec"
      else
	config = Dir.pwd + "/rubyspec/ruby.1.9.mspec"
      end
      command = %W[bin/ruby mspec/bin/mspec -V -f s -B #{config} -t #{rubybin}]
      # command << "rubyspec"
      command.concat ChkBuild::Ruby.rubyspec_exclude_directories(excludes, ["rubyspec"])
      command << {
	:section=>"rubyspec"
      }
      b.run(*command)
    }
    if /^Finished/ !~ b.logfile.get_section('rubyspec')
      Pathname("rubyspec").children.reject {|f| !f.directory? }.sort.each {|d|
	d.stable_find {|f|
	  Find.prune if %w[.git fixtures nbproject shared tags].include? f.basename.to_s
	  next if /_spec\.rb\z/ !~ f.basename.to_s
	  Find.prune if excludes.any? {|e| f.to_s.start_with?("#{e}/") }
	  s = f.lstat
	  next if !s.file?
	  b.catch_error {
	    FileUtils.rmtree "rubyspec_temp"
	    if %r{branches/ruby_1_8} =~ ruby_branch
	      config = ruby_build_dir + "rubyspec/ruby.1.8.mspec"
	    else
	      config = ruby_build_dir + "rubyspec/ruby.1.9.mspec"
	    end
	    command = %W[bin/ruby mspec/bin/mspec -V -f s -B #{config} -t #{rubybin}]
	    command << f.to_s
	    command << {
	      :section=>f.to_s
	    }
	    b.run(*command)
	  }
	}
      }
    end
  end

  Dir.chdir('ruby') {
    relname = nil
    case ruby_branch
    when 'branches/ruby_1_9_2',
         'branches/ruby_1_9_1',
         'branches/ruby_1_8',
         'branches/ruby_1_8_7',
         'branches/ruby_1_8_6',
         'branches/ruby_1_8_5'
      # "make dist" doesn't support BRANCH@rev.
      relname = nil
    else
      relname = "#{ruby_branch}@#{ruby_svn_rev}"
    end
    if relname
      b.make("dist", "RELNAME=#{relname}")
    end
  }
}

ChkBuild.define_title_hook('ruby', "svn-info/ruby") {|title, log|
  if /^Last Changed Rev: (\d+)$/ =~ log
    title.update_title(:revision, "rev:#{$1}")
  end
}

ChkBuild.define_title_hook('ruby', "configure") {|title, log|
  if /^checking target system type\.\.\. (\S+)$/ =~ log
    title.update_title(:version, "#{title.suffixed_name} [#{$1}]")
  end
}

ChkBuild.define_title_hook('ruby', "miniversion") {|title, log|
  if /^ruby [0-9].*$/ =~ log
    ver = $&
    ss = title.suffixed_name.split(/-/)[1..-1].reject {|s| /\A(trunk|1\.8)\z/ =~ s }
    ver << " [#{ss.join(',')}]" if !ss.empty?
    title.update_title(:version, ver)
  end
}

ChkBuild.define_title_hook('ruby', "version") {|title, log|
  if /^ruby [0-9].*$/ =~ log
    ver = $&
    ss = title.suffixed_name.split(/-/)[1..-1].reject {|s| /\A(trunk|1\.8)\z/ =~ s }
    ver << " [#{ss.join(',')}]" if !ss.empty?
    title.update_title(:version, ver)
  end
}

ChkBuild.define_failure_hook('ruby', "btest") {|log|
  if /^FAIL (\d+)\/\d+ tests failed/ =~ log
    "#{$1}BFail"
  end
}

ChkBuild.define_failure_hook('ruby', "test-knownbug") {|log|
  if /^FAIL (\d+)\/\d+ tests failed/ =~ log
    "#{$1}KB"
  elsif /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors$/ =~ log
    failures = $1.to_i
    errors = $2.to_i
    if failures != 0 || errors != 0
      "KB#{failures}F#{errors}E"
    end
  end
}

ChkBuild.define_failure_hook('ruby', "test.rb") {|log|
  if /^end of test/ !~ log
    if /^test: \d+ failed (\d+)/ =~ log || %r{^not ok/test: \d+ failed (\d+)} =~ log
      "#{$1}NotOK"
    end
  end
}

ChkBuild.define_failure_hook('ruby', "test-all") {|log|
  if /.*^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors$/m =~ log
    failures = $1.to_i
    errors = $2.to_i
    if failures != 0 || errors != 0
      "#{failures}F#{errors}E"
    end
  elsif /.*^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors, (\d+) skips$/m =~ log
    failures = $1.to_i
    errors = $2.to_i
    if failures != 0 || errors != 0
      "#{failures}F#{errors}E"
    end
  end
}

ChkBuild.define_failure_hook('ruby', "rubyspec") {|log|
  if /.*^\d+ files?, \d+ examples?, \d+ expectations?, (\d+) failures?, (\d+) errors?$/m =~ log
    failures = $1.to_i
    errors = $2.to_i
    if failures != 0 || errors != 0
      "rubyspec:#{failures}F#{errors}E"
    end
  end
}

ChkBuild.define_title_hook('ruby', nil) {|title, log|
  log = log.gsub(/^LASTLOG .*/, '') # skip commit message.
  log = log.sub(/combination may cause frequent hang or segmentation fault|hangs or segmentation faults/, '') # skip tk message.
  mark = ''
  numbugs = ChkBuild::Ruby.count_prefix(/\[BUG\]/i, log) and mark << " #{numbugs}[BUG]"
  numsegv = ChkBuild::Ruby.count_prefix( /segmentation fault|signal segv/i, log) and
    mark << " #{numsegv}[SEGV]"
  numsigbus = ChkBuild::Ruby.count_prefix(/signal SIGBUS/i, log) and mark << " #{numsigbus}[SIGBUS]"
  numsigill = ChkBuild::Ruby.count_prefix(/signal SIGILL/i, log) and mark << " #{numsigill}[SIGILL]"
  numsigabrt = ChkBuild::Ruby.count_prefix(/signal SIGABRT/i, log) and mark << " #{numsigabrt}[SIGABRT]"
  numfatal = ChkBuild::Ruby.count_prefix(/\[FATAL\]/i, log) and mark << " #{numfatal}[FATAL]"
  mark.sub!(/\A /, '')
  title.update_title(:mark, mark)
}

# #define RUBY_RELEASE_DATE "2013-04-06"
ChkBuild.define_diff_preprocess_gsub('ruby', /^\#define RUBY_RELEASE_DATE ".*"/) {|match|
  '#define RUBY_RELEASE_DATE "<year>-<mm>-<dd>"'
}

# #define RUBY_RELEASE_YEAR 2013
# #define RUBY_RELEASE_MONTH 4
# #define RUBY_RELEASE_DAY 6
ChkBuild.define_diff_preprocess_gsub('ruby', /^\#define RUBY_RELEASE_(YEAR|MONTH|DAY) \d+/) {|match|
  "\#define RUBY_RELEASE_#{match[1]} <num>"
}

# ruby 1.9.2dev (2009-12-07 trunk 26037) [i686-linux]
# ruby 1.9.1p376 (2009-12-07 revision 26040) [i686-linux]
# | ruby 1.9.2dev (2010-02-18 trunk 26704) [x86_64-linux]
ChkBuild.define_diff_preprocess_gsub('ruby', /ruby [0-9.a-z]+ \(.*\) \[.*\]$/) {|match|
  "ruby <version>"
}

# tcltklib: tcltklib 2010-08-25 :: Ruby2.0.0 (2012-02-20) with pthread :: Tcl8.5.10(without stub)/Tk8.5.10(without stub) with tcl_threads
ChkBuild.define_diff_preprocess_gsub('ruby', /^tcltklib: (.*)Ruby[\d.]+ \([\d-]+\)/) {|match|
  "tcltklib: #{match[1]}Ruby<version> (<release-date>)"
  "ruby <version>"
}

# file.c:884: warning: comparison between signed and unsigned
# vm.c:2012:5: warning: "OPT_BASIC_OPERATIONS" is not defined
#
# Doxygen:
# /home/akr/chkbuild/tmp/build/ruby-trunk/20100816T014700Z/ruby/ext/ripper/ripper.y:18: Warning: include file ruby/ruby.h not found, perhaps you forgot to add its directory to INCLUDE_PATH?
# /home/akr/chkbuild/tmp/build/ruby-trunk/20100816T014700Z/ruby/pack.c:89: Problem during constant expression evaluation: syntax error
#        from /extdisk/chkbuild/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/test/ruby/test_autoload.rb:82:in `block (2 levels) in test_threaded_accessing_constant'
ChkBuild.define_diff_preprocess_gsub_state('ruby', /\A([^:]*:)(\d+)(:((?:\d+:)? (?:[Ww]arning: |Problem )|in `.*').*)/) {|match, state|
  pre, linenum, post = match[1], match[2], match[3]
  warnhash = state[:warnhash] ||= {}
  key = "#{pre}<linenum>#{post}"
  id_next, warnhash2 = warnhash[key] ||= ["a", {}]
  if warnhash2[linenum]
    id = warnhash2[linenum]
  else
    warnhash2[linenum] = id = id_next.dup
    id_next.succ!
  end
  "#{pre}<line_#{id}>#{post}"
}

# Doxygen:
# Running dot for graph 1/405
ChkBuild.define_diff_preprocess_gsub('ruby', %r{Running dot for graph \d+/\d+}) {|match|
  'Running dot for graph <num>/<num>'
}

# Doxygen:
# Inserting map/figure 1/342
ChkBuild.define_diff_preprocess_gsub('ruby', %r{Inserting map/figure \d+/\d+}) {|match|
  'Inserting map/figure <num>/<num>'
}

# gcc ... -DRUBY_RELEASE_DATE=\"2010-05-04\" ... tcltklib.c
ChkBuild.define_diff_preprocess_gsub('ruby', /-DRUBY_RELEASE_DATE=\\"\d+-\d\d-\d\d\\"/) {|match|
  '-DRUBY_RELEASE_DATE=\"YYYY-MM-DD\"'
}

# done.  (0.07user 0.01system 0.05elapsed)
ChkBuild.define_diff_preprocess_gsub('ruby', /^done\.  \(\d+\.\d\duser \d+\.\d\dsystem \d+\.\d\delapsed\)/) {|match|
  "done.  (X.XXuser X.XXsystem X.XXelapsed)"
}

# rdoc:
#   0% [ 1/513]   eval.c
#   0% [ 2/513]   prelude.c
# ...
#  99% [512/513]   ext/zlib/zlib.c
# 100% [513/513]   doc/re.rdoc
ChkBuild.define_diff_preprocess_gsub('ruby', %r{^\s*\d+%\s+\[\s*\d+/\d+\]}) {|match|
  "XXX% [XXX/XXX]"
}

# test_exception.rb #1 test_exception.rb:1
ChkBuild.define_diff_preprocess_gsub('ruby', /\#\d+ test_/) {|match|
  "#<n> test_"
}

# test/unit:
#  28) Error:
#  33) Failure:
#  2) Skipped:
# rubyspec:
# 61)
ChkBuild.define_diff_preprocess_gsub('ruby', /^ *\d+\)( Error:| Failure:| Skipped:|$)/) {|match|
  " <n>)#{match[1]}"
}

# rubyspec
# -- reports aborting on a killed thread (FAILED - 9)
# -- flattens self (ERROR - 21)
ChkBuild.define_diff_preprocess_gsub('ruby', /\((FAILED|ERROR) - \d+\)$/) {|match|
  "(#{match[1]} - <n>)"
}

ChkBuild.define_diff_preprocess_gsub('ruby', %r{\((druby|drbssl)://(#{ChkBuild::Ruby::DOMAINPAT}):\d+\)}o) {|match|
  "(#{match[1]}://#{match[2]}:<port>)"
}

# [2006-09-24T12:48:49.245737 #6902] ERROR -- : undefined method `each' for #<String:0x447fc5e4> (NoMethodError)
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\[\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+) \#(\d+)\]}o) {|match|
  "[YYYY-MM-DDThh:mm:ss" + match[1].gsub(/\d/, 's') + " #<pid>]"
}

# #<String:0x4455ae94
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\#<[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*:0x[0-9a-f]+}o) {|match|
  match[0].sub(/[0-9a-f]+\z/) { '<address>' }
}

# #<#<Class:0xXXXXXXX>:0x0e87dd00
# NoMethodError: undefined method `join' for #<#<Class:0x<address>>::Enum:0x00000000d76e98 @elements=[]>
# order sensitive.  this should be applied after the above.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{(\#<\#<Class:0x<address>>(?:::[A-Z][A-Za-z0-9_]*)*:0x)([0-9a-f]+)}o) {|match|
  match[1] + '<address>'
}

# #<BigDecimal:403070d8,
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\#<BigDecimal:[0-9a-f]+}) {|match|
  match[0].sub(/[0-9a-f]+\z/) { '<address>' }
}

# but got ThreadError (uncaught throw `blah' in thread 0x23f0660)
ChkBuild.define_diff_preprocess_gsub('ruby', %r{thread 0x[0-9a-f]+}o) {|match|
  match[0].sub(/[0-9a-f]+\z/) { '<address>' }
}

# XSD::ValueSpaceError: {http://www.w3.org/2001/XMLSchema}dateTime: cannot accept '2007-02-01T23:44:2682967.846399999994901+09:00'.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\d+\.\d+}o) {|match|
  s = match[0]
  chars = %w[Y M D h m s s]
  s.gsub!(/\d+/) { "<#{chars.shift}>" }
  s
}

# mkdir -p /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/fileutils.rb.23661/tmpdir/dir/
ChkBuild.define_diff_preprocess_gsub('ruby', %r{/tmp/fileutils.rb.\d+/tmpdir/}o) {|match|
  '/tmp/fileutils.rb.<n>/tmpdir/'
}

# connect to #<Addrinfo: [::1]:54046 TCP>.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\#<Addrinfo: \[::1\]:\d+}o) {|match|
  '#<Addrinfo: [::1]:<port>'
}

# NoMethodError: undefined method `mode' for #<File:fd 17>
ChkBuild.define_diff_preprocess_gsub('ruby', %r{\#<File:fd \d+>}o) {|match|
  '#<File:fd n>'
}

ChkBuild.define_diff_preprocess_gsub('ruby', /^Elapsed: [0-9.]+s/) {|match|
  "Elapsed: <t>s"
}

# test/unit:
# Finished in 139.785699 seconds.
# rubyspec:
# Finished in 31.648244 seconds
ChkBuild.define_diff_preprocess_gsub('ruby', /^Finished in [0-9.]+ seconds/) {|match|
  "Finished in <t> seconds"
}

# test/unit (parallel):
# Finished ptests in 2.061711s, 3.8803 tests/s, 0.9701 assertions/s.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{^Finished ptests in [0-9.]+s, [0-9.]+ tests/s, [0-9.]+ assertions/s.}) {|match|
  "Finished ptests in <n>s, <n> tests/s, <n> assertions/s."
}

# miniunit:
# Finished tests in 527.896930s, 16.5241 tests/s, 4174.6880 assertions/s.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{^Finished tests in [0-9.]+s, [0-9.]+ tests/s, [0-9.]+ assertions/s\.}) {|match|
  "Finished tests in <n>s, <n> tests/s, <n> assertions/s."
}

# /tmp/test_rubygems_18634
ChkBuild.define_diff_preprocess_gsub('ruby', %r{/tmp/test_rubygems_\d+}o) {|match|
  '/tmp/test_rubygems_<pid>'
}

# <buildtime>/mspec/lib/mspec/mocks/mock.rb:128:in `__ms_70044980_respond_to?__'
ChkBuild.define_diff_preprocess_gsub('ruby', %r{__ms_-?\d+_}) {|match|
  '__ms_<object_id>_'
}

# called with unexpected arguments (__mspec_70137220810560_respond_to_missing?__ false)
ChkBuild.define_diff_preprocess_gsub('ruby', %r{__mspec_-?\d+_}) {|match|
  '__mspec_<object_id>_'
}

# miniunit:
# Complex_Test#test_parse: 0.01 s: .
# Test_REXMLStreamParser#test_fault: -0.58 s: .
ChkBuild.define_diff_preprocess_gsub('ruby', %r{-?\d+\.\d\d s: }) {|match|
  '<elapsed> s: '
}

# miniunit:
# CGIMultipartTest#test_cgi_multipart_badbody = 0.01 s = .
ChkBuild.define_diff_preprocess_gsub('ruby', %r{-?\d+\.\d\d s =}) {|match|
  '<elapsed> s ='
}

# Errno::ENOENT: No such file or directory - /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/generate_test_12905.csv
ChkBuild.define_diff_preprocess_gsub('ruby', %r{generate_test_\d+.csv}) {|match|
  'generate_test_<digits>.csv'
}

# ruby exit stauts is not success: #<Process::Status: pid 7502 exit 1>
ChkBuild.define_diff_preprocess_gsub('ruby', /\#<Process::Status: pid \d+ /) {|match|
  '#<Process::Status: pid <pid> '
}

# Doxygen:
# Version of /home/akr/chkbuild/tmp/build/ruby-trunk/20100104T093900/ruby/doc/images/.svn/all-wcprops : 26238
ChkBuild.define_diff_preprocess_gsub('ruby', /^(Version of .* : )\d+$/) {|match|
  match[1] + "<num>"
}

# test-all:
# 6937 tests, 2165250 assertions, 6 failures, 0 errors, 0 skips
ChkBuild.define_diff_preprocess_gsub('ruby', /^(\d+ tests, )\d+( assertions, \d+ failures, \d+ errors, \d+ skips)$/) {|match|
  match[1] + "<num>" + match[2]
}

# Test run options: --seed 27850 --verbose
ChkBuild.define_diff_preprocess_gsub('ruby', /Test run options: --seed \d+ --verbose/) {|match|
  'Test run options: --seed <num> --verbose'
}

# <#<Errno::EIO: Input/output error - /dev/pts/0>>.
ChkBuild.define_diff_preprocess_gsub('ruby', %r{/dev/pts/\d+}) {|match|
  "/dev/pts/N"
}

# rubyspec:
# 2932 files, 13911 examples, 182945 expectations, 34 failures, 24 errors
# 1 file, 36 examples, 52766 expectations, 0 failures, 0 errors
ChkBuild.define_diff_preprocess_gsub('ruby', /^(\d+ files?, \d+ examples?, )\d+( expectations?, \d+ failures?, \d+ errors?)$/) {|match|
  match[1] + "<num>" + match[2]
}

# MinitestSpec#test_needs_to_verify_nil: <elapsed> s: .
# RUNIT::TestAssert#test_assert_send: .
ChkBuild.define_diff_preprocess_sort('ruby', /\A[A-Z][A-Za-z0-9_]+(::[A-Z][A-Za-z0-9_]+)*\#/)

# - returns self as a symbol literal for :$*
ChkBuild.define_diff_preprocess_sort('ruby', /\A- returns self as a symbol literal for :/)

# make dist
#
# + make dist RELNAME=trunk@29063
# ruby ./tool/make-snapshot tmp trunk@29063
# Exporting trunk@29063
# Exported revision 29063.
#
# + make dist RELNAME=branches/ruby_1_9_3@32655
# ruby ./tool/make-snapshot tmp branches/ruby_1_9_3@32655
# Exporting branches/ruby_1_9_3@32655
#
ChkBuild.define_diff_preprocess_gsub('ruby', %r{(RELNAME=[0-9A-Za-z/_.-]+@)\d+}) {|match| "#{match[1]}<rev>" }
ChkBuild.define_diff_preprocess_gsub('ruby', %r{(make-snapshot tmp [0-9A-Za-z/_.-]+@)\d+}) {|match| "#{match[1]}<rev>" }
ChkBuild.define_diff_preprocess_gsub('ruby', %r{(Exporting [0-9A-Za-z/_.-]+@)\d+}) {|match| "#{match[1]}<rev>" }
ChkBuild.define_diff_preprocess_gsub('ruby', %r{(Exported revision )\d+}) {|match| "#{match[1]}<rev>" }

# make dist
# make[1]: Entering directory `/home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/ruby-snapshot20100821-16136-p60p7s/ruby-1.9.3-r29063'
# make[1]: Leaving directory `/home/chkbuild/build/ruby-trunk/<buildtime>/tmp/ruby-snapshot-9557-11854/ruby-2.0.0-r33541'
ChkBuild.define_diff_preprocess_gsub('ruby', %r{ruby-snapshot[-0-9a-z]+/ruby-[0-9a-z.-]+}) {|match|
  "ruby-snapshot<tmp>/ruby-<verrev>"
}

# TestAutoload#test_threaded_accessing_constant = /home/akr/chkbuild/tmp/build/ruby-trunk/20111022T114531Z/ruby/test/ruby/test_autoload.rb:81: warning: loading in progress, circular require considered harmful - /home/akr/chkbuild/tmp/build/ruby-trunk/20111022T114531Z/tmp/autoload20111022-5038-5nchmi.rb
# TestRequire#test_load2 = /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/lib/rubygems/custom_require.rb:<line_a>: warning: loading in progress, circular require considered harmful - /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/bug575420111221-16977-19vmgph.rb
# /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/lib/rubygems/custom_require.rb:<line_a>: warning: loading in progress, circular require considered harmful - /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/bug575420111221-16977-19vmgph.rb
# TestException#test_exception_in_exception_equal = /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/tmp/test_exception_in_exception_equal20120212-20753-538yy.rb:<line_a>: warning: possibly useless use of == in void context
#
ChkBuild.define_diff_preprocess_gsub('ruby', %r{/tmp/(autoload|bug5754|test_exception_in_exception_equal)\d+-\d+-[0-9a-z]+}) {|match|
  "/tmp/#{match[1]}<tmp>"
}

# make dist
# creating bzip tarball... /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/tmp/ruby-1.9.3-r29063.tar.bz2 done
# creating gzip tarball... /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/tmp/ruby-1.9.3-r29063.tar.gz done
# creating zip archive... /home/akr/chkbuild/tmp/build/ruby-trunk/<buildtime>/ruby/tmp/ruby-1.9.3-r29063.zip done
ChkBuild.define_diff_preprocess_gsub('ruby', %r{ruby-[0-9a-z.-]+\.(tar|zip)}) {|match|
  "ruby-<verrev>.#{match[1]}"
}

# make dist
#   SIZE:   8727493 bytes
ChkBuild.define_diff_preprocess_gsub('ruby', %r{^( *SIZE:\s+)[0-9]+}) {|match|
  "#{match[1]}<size>"
}

# make dist
#   MD5:    fc3ac1bff7e906cbca72c3dffce638b0
#   SHA256: 677a188cb312453da596e21d5b843ba96d332f8ff93a247cd6c88d93f5e74093
ChkBuild.define_diff_preprocess_gsub('ruby', %r{^( *(MD5|SHA256):\s+)[0-9a-f]+}) {|match|
  "#{match[1]}<digest>"
}

# segment       = *pchar
# pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
# unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
# pct-encoded   = "%" HEXDIG HEXDIG
# sub-delims    = "!" / "$" / "&" / "'" / "(" / ")"
#               / "*" / "+" / "," / ";" / "="
segment_regexp = '(?:[A-Za-z0-9\-._~!$&\'()*+,;=:@]|%[0-9A-Fa-f][0-9A-Fa-f])*'

ChkBuild.define_file_changes_viewer('svn',
  %r{\Ahttp://svn\.ruby-lang\.org/repos/ruby (#{segment_regexp}(/#{segment_regexp})*)?\z}o) {
  |match, reptype, pat, checkout_line|
  # http://svn.ruby-lang.org/repos/ruby
  # http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?diff_format=u

  mod = match[1]
  mod = nil if mod && mod.empty?
  ChkBuild::ViewVC.new('http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?diff_format=u', false, mod)
}


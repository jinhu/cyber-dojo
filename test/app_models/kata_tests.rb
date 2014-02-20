require File.dirname(__FILE__) + '/../test_helper'
require File.dirname(__FILE__) + '/stub_disk'
require File.dirname(__FILE__) + '/stub_git'

class KataTests < ActionController::TestCase

  def setup
    Thread.current[:disk] = @disk = StubDisk.new
    Thread.current[:git] = @git = StubGit.new
    @dojo = Dojo.new('stubbed')
    @id = '45ED23A2F1'
    @kata = @dojo[@id]    
  end
  
  def teardown
    Thread.current[:disk] = nil
    Thread.current[:git] = nil
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "id is from ctor" do
    assert_equal @id, @kata.id    
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "exists? false then true when kata's dir exists" do
    assert !@kata.exists?
    @disk[@kata.dir] = true
    assert @kata.exists?
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "dir does not end in slash" do
    assert !@kata.dir.end_with?(@disk.file_separator)
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "dir does not have doubled separator" do
    doubled_separator = @disk.file_separator * 2
    assert_equal 0, @kata.dir.scan(doubled_separator).length    
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "dir is based on cyberdojo root_dir and id" do
    assert @kata.dir.match(@dojo.dir), "root_dir"
    uuid = Uuid.new(@id)
    assert @kata.dir.match(uuid.inner), "id.inner"
    assert @kata.dir.match(uuid.outer), "id.outer"
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "creation saves manifest in kata dir" do
    manifest = { :id => @id }    
    kata = @dojo.create_kata(manifest)
    assert_equal [ [ 'manifest.rb', manifest.inspect ] ], @disk.write_log[@kata.dir]    
    assert_equal nil, @disk.read_log[@kata.dir]
  end
    
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    
  test "created date is read from manifest" do
    now = [2013,6,29,14,24,51]
    manifest = {
      :created => now,
      :id => @id
    }    
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    assert_equal Time.mktime(*now), @kata.created    
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "age_in_seconds is calculated from creation date in manifest" do
    now = [2013,6,29,14,24,51]
    manifest = {
      :created => now,
      :id => @id
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    seconds = 5
    now = now[0...-1] + [now.last + seconds ]
    assert_equal seconds, @kata.age_in_seconds(Time.mktime(*now))    
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "language name is read from manifest" do
    language = 'Wibble'
    manifest = {
      :language => language,
      :id => @id
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    assert_equal language, @kata.language.name
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "exercise name is read from manifest" do
    exercise = 'Tweedle'
    manifest = {
      :exercise => exercise,
      :id => @id
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    assert_equal exercise, @kata.exercise.name    
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "visible_files are read from manifest" do
    visible_files = {
        'wibble.h' => '#include <stdio.h>',
        'wibble.c' => '#include "wibble.h"'
    }
    manifest = {
      :id => @id,
      :visible_files => visible_files
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    assert_equal visible_files, @kata.visible_files
  end  
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "Kata.exists? returns false before kata is created then true after kata is created" do
    assert !@kata.exists?, "!kata.exists? before created"
    manifest = { :id => @id }
    @dojo.create_kata(manifest)
    assert @kata.exists?, "Kata.exists? after created"
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  test "kata[avatar] when avatar does not exist" do
    avatar = @kata['lion']
    assert !avatar.exists?
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "kata[avatar] when avatar does exist" do
    avatar = @kata['lion']
    @disk[avatar.dir] = true
    assert avatar.exists?    
  end
  
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "you can create an avatar in a kata" do
    language = @dojo.language('C')
    manifest = {
      :id => @id,
      :language => language.name
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    @disk[language.dir,'manifest.json'] = JSON.unparse({ })
    kata = @dojo.create_kata(manifest)
    assert 'hippo', kata['hippo'].name
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "multiple avatars in a kata are all seen" do
    language = @dojo.language('C')
    manifest = {
      :id => @id,
      :visible_files => {
        'name' => 'content for name'
      },
      :language => language.name
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    @disk[language.dir,'manifest.json'] = JSON.unparse({ })
    kata = @dojo.create_kata(manifest)
    Avatar.create(kata, 'lion') ####
    Avatar.create(kata, 'hippo') ####
    avatars = kata.avatars
    assert_equal 2, avatars.length
    assert_equal ['hippo','lion'], avatars.collect{|avatar| avatar.name}.sort
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test "start_avatar succeeds once for each avatar name then fails" do
    language = @dojo.language('C')
    manifest = {
      :id => @id,
      :language => language.name,
      :visible_files => {
        'wibble.h' => '#include <stdio.h>'
      }      
    }
    @disk[@kata.dir,'manifest.rb'] = manifest.inspect
    @disk[language.dir, 'manifest.json'] = JSON.unparse({ })
    kata = @dojo.create_kata(manifest)
    created = [ ]
    Avatar.names.length.times do |n|
      avatar = kata.start_avatar
      assert_not_nil avatar
      created << avatar
    end
    assert_equal Avatar.names.length, created.collect{|avatar| avatar.name}.uniq.length        
    avatar = kata.start_avatar
    assert_nil avatar
  end

end

# Git - Under the Hood
This tutorial covers a few interesting git topics. We'll talk about:
- .git Folder Contents
- Git Objects
- Working with Tags
- Rewriting History
- Finding Commits
- Git Hooks
- Objects and Pack Files

## Ok Let's Get Started
I'm assuming that you have **git** and **ruby** installed, and that you have some familiarity with the basics of adding files to git and making commits. I also use the **tree** utility during this tutorial, so you'll need to have that installed or just use **ls** to inspect directories instead.

## .git Folder Contents
Let's start by creating an empty repository:
```bash
$ mkdir temp-repo && cd temp-repo && git init
```

Let's see what we get for our efforts:
```bash
$ ls -l .git
total 24
-rw-r--r--   1 jessehill  staff   23 Aug 18 11:29 HEAD
-rw-r--r--   1 jessehill  staff  137 Aug 18 11:29 config
-rw-r--r--   1 jessehill  staff   73 Aug 18 11:29 description
drwxr-xr-x  11 jessehill  staff  374 Aug 18 11:29 hooks/
drwxr-xr-x   3 jessehill  staff  102 Aug 18 11:29 info/
drwxr-xr-x   4 jessehill  staff  136 Aug 18 11:29 objects/
drwxr-xr-x   4 jessehill  staff  136 Aug 18 11:29 refs/
```
What's in that **HEAD** file?
```bash
$ cat .git/HEAD
ref: refs/heads/master
```
Our HEAD file is just a text file that lists a git ref that the HEAD should point to. The HEAD ref defaults to master. That seems reasonable. What if we look at our repository's history?
```bash
$ git log
fatal: bad default revision 'HEAD'
```
We get this error of course because we have no commits and so *refs/head/master* doesn't exist yet. Taking a look at our refs directory confirms this.
```bash
$ tree .git/refs/
.git/refs/
├── heads
└── tags

2 directories, 0 files
```
Ok, what branch are we on?
```bash
$ git branch
(No output)
```
So, we don't have a branch yet either. When we make our first commit, we'll automagically get a master ref.
```bash
$ echo "Hi" >> hello.txt && git add . && git commit -m "Hello"
[master (root-commit) f31e784] Hello
 1 file changed, 1 insertion(+)
 create mode 100644 hello.txt
$ ls .git/refs/heads
master
```
Ok, so there it is - we have a **master** now. 

What if we create a new branch and then check again?
```bash
$ git checkout -b develop
Switched to a new branch 'develop'
~/Documents/git/temp-repo:
$ tree .git/refs/
.git/refs/
├── heads
│   ├── develop
│   └── master
└── tags

2 directories, 2 files
```
So we have some idea now where git stores information about our branches. Let's take a look at what's in the master ref file.
```bash
$ cat .git/refs/heads/master
f31e784077dd3cdf6ba0c8b0cb6a63c7f568a012
```
So again, this is just a text file. It lists the hash of the commit that the **master** ref points to. 

Let's take a look in the config file.
```bash
$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
```

There isn't much in the config file by default. It's perhaps important to note that this file is not versioned and shared. If we create an alias:
```bash
$ git config alias.co checkout
$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[alias]
	co = checkout
```
We see that we have an entry added to the config file, but if we clone the repo:
```bash
$ cd .. && git clone temp-repo temp-repo-2 && cat temp-repo-2/.git/config
Cloning into 'temp-repo-2'...
done.
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = /Users/jessehill/Documents/git/temp-repo
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "develop"]
	remote = origin
	merge = refs/heads/develop
```
We can see that we don't have the alias in the cloned repository. The config contents are local to the copy of the repository.

Let's clean up and go back to our original repository:

```bash
$ rm -rf temp-repo-2 && cd temp-repo
```

Ok, what's in that hooks directory?
```bash
$ ls .git/hooks
applypatch-msg.sample      pre-applypatch.sample      pre-rebase.sample
commit-msg.sample          pre-commit.sample          prepare-commit-msg.sample
post-update.sample         pre-push.sample            update.sample
```
Interesting. These look like scripts that we could enable in order to hook into git's lifecycle. We'll take a closer look at these files later.

There's an info/exclude file:
```bash
$ cat .git/info/exclude
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
```
What's that thing for? Why not just use .gitignore? Well, you'll mostly use .gitignore, since it's versioned and shared and can be specified in each directory as needed. The .git/info/exclude file should be used for personal exclusions (say, IDE config) that won't be shared as part of the repository when it is cloned.

## Git Objects
### Blobs
Let's start with a clean repository again and add a file:

```bash
$ cd .. && rm -rf temp-repo && mkdir temp-repo && cd temp-repo && git init
$ echo "It's fun to write Clojure code." >> comments.txt
```

Do we have any objects yet?
```bash
$ find .git/objects -type f | wc -l
       0
```

Ok, no, not yet. Let's stage the file:
```bash
$ git add comments.txt
```
How about now?
```bash
$ find .git/objects -type f | wc -l
       1
```
Ok, cool! We have an object! What should we expect the hash of that object should be?
```bash
$ git hash-object comments.txt
d65a67c2695f0252b4dd846ca20a60ee9dc1f981
```
Git computes a SHA1 hash from the file content and uses this hash to determine the file path for the object. Let's see if we can find it in the objects directory:
```bash
$ tree .git/objects/
.git/objects/
├── d6
│   └── 5a67c2695f0252b4dd846ca20a60ee9dc1f981
├── info
└── pack

3 directories, 1 file
```

Yep, that matches our hash. Note the first two character of the hash are used for the directory name and the rest form the file name.

Let's see if we can take a look at what is in that object.
```bash
$ git cat-file -p d65a
It's fun to write Clojure code.
```
That looks like what we expected. What's the type of that thing?
```bash
$ git cat-file -t d65a
blob
```
It's a blob. How exciting!
> A blob is a Binary Large Object. They're used to store larger objects that have an unknown format - typically for images, audio, or executables in a database. In git they're used to store the content of all files in the working directory.

Let's look at the format of the file itself. Create a ruby script that looks like this:
```ruby
#!/usr/bin/ruby
require 'zlib'
filename = ARGV[0]
content = File.open(filename, 'rb') { |f| f.read }
unzipped = Zlib::Inflate.inflate(content)
puts unzipped
```
The script inflates a file's contents and prints them to the console. I've named my script **decode-commit.rb**.

Let's run it on our object file:
```bash
$ ruby decode-commit.rb .git/objects/d6/5a67c2695f0252b4dd846ca20a60ee9dc1f981
blob 32It's fun to write Clojure code.
```
So that's the blob object format. A header of the object type and object length are prepended to the content, and then the whole thing is compressed with zlib and written to the directory and file name that correspond to the SHA1 hash of the file content.

### Tree and Commit Objects
Let's write our index (staging area) out to a git object.
```bash
$ git write-tree
56cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
$ tree .git/objects/
.git/objects/
├── 56
│   └── cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
├── d6
│   └── 5a67c2695f0252b4dd846ca20a60ee9dc1f981
├── info
└── pack

4 directories, 2 files
```
So we're up to two objects. If we take a look at our new one (56cb) we can see what a **tree** looks like:
```bash
$ git cat-file -t 56cb
tree
$ git cat-file -p 56cb
100644 blob d65a67c2695f0252b4dd846ca20a60ee9dc1f981	comments.txt
```
The tree will contain a row for each object in the tree's directory. The first column shows object type and file permissions. The second column lists the object type (blob or tree). The third column lists the hash for the object content. The final column states the name to use for the object when it's written to the working directory.

Let's commit our changes:
```bash
$ git commit -m "Adds comments file"
[master (root-commit) a814d2d] Adds comments file
 1 file changed, 1 insertion(+)
 create mode 100644 comments.txt
```
> Note that your commit will not have the a814d2d hash. You can probably guess why that is - the hash is based on the content of the file and the file includes timestamps, which will differ on your machine. So it makes sense that your hash will vary.

Now how many objects do we have now?
```bash
$ tree .git/objects/
.git/objects/
├── 56
│   └── cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
├── a8
│   └── 14d2d48078dffe11d661456c1062ad9e6bad96
├── d6
│   └── 5a67c2695f0252b4dd846ca20a60ee9dc1f981
├── info
└── pack

5 directories, 3 files
```
We're starting to get a lot of objects to look through. In order to help out, let's write a quick *cat-objects.rb* script - open a file and paste in this content:
```ruby
#!/usr/bin/ruby
require 'find'

Find.find(".git/objects") do |path|
  if FileTest.file?(path)
    dirname = File.dirname(path)
    hash_prefix = File.basename(dirname)
    hash = hash_prefix + File.basename(path)
    puts "Hash: " + hash
    puts "Type: " + `git cat-file -t #{hash}`
    puts `git cat-file -p #{hash}`
    puts
  end
end
```
Now we can run the script to *cat* out our objects:
```bash
$ ruby cat-objects.rb
Hash: 56cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
Type: tree
100644 blob d65a67c2695f0252b4dd846ca20a60ee9dc1f981	comments.txt

Hash: a814d2d48078dffe11d661456c1062ad9e6bad96
Type: commit
tree 56cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
author Jesse Hill <jessebhill@gmail.com> 1472482925 -0400
committer Jesse Hill <jessebhill@gmail.com> 1472482925 -0400

Adds comments file

Hash: d65a67c2695f0252b4dd846ca20a60ee9dc1f981
Type: blob
It's fun to write Clojure code.
```
Ok - that it looks like we have a new **commit** object. Notice that the first line of the commit points to a tree object at **a814**. That seems to match up to our tree object from the previous step. The commit contains author and committer meta-data as well as timestamps. You'll also notice the commit comment at the end.
> Each time you make a commit, git will write a new tree object to the store on its own. We took the extra step on our own here just to be more explicit.

### When are Objects Added?
Let's try adding some more objects.
```bash
$ echo 'No seriously, Clojure is really fun!' >> another-comment.txt
```
Ok, now how many objects do we have?
```bash
$ find .git/objects -type f | wc -l
       3
```
Still 3 - just creating the file wasn't enough to generate an object. Let's add the file to the staging area and try again:
```bash
$ git add another-comment.txt
$ find .git/objects -type f | wc -l
       4
```
Ok! That did it - adding the file to the staging area caused an object to be created. Let's take a peek at the objects:
```bash
$ tree .git/objects/
.git/objects/
├── 56
│   └── cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
├── 5e
│   └── 06553fe36d4faf161cebbb263b07f354379735
├── a8
│   └── 14d2d48078dffe11d661456c1062ad9e6bad96
├── d6
│   └── 5a67c2695f0252b4dd846ca20a60ee9dc1f981
├── info
└── pack

6 directories, 4 files
```
Now, let's really express our enthusiasm here:
```bash
$ echo 'Clojure is great!!!' >> another-comment.txt
$ git add another-comment.txt
$ find .git/objects -type f | wc -l
       5
```
We're up to 5 objects now. You might have only expected four objects - one for each file, one for our tree and commit. We have 5 because the object for the version of the file that was staged but not committed is still here. It's a dangling object - it's in our repository but there's no commit pointing to it and the index is no longer referencing it.

We can see this by running the **git fsck** command:
```bash
$ git fsck
Checking object directories: 100% (256/256), done.
dangling blob 5e06553fe36d4faf161cebbb263b07f354379735
```

Now what happens, if we copy and add our latest file:
```bash
$ cp another-comment.txt another-comment-copy.txt
$ git add another-comment-copy.txt
$ find .git/objects -type f | wc -l
       5
```
Woah! Interesting! Did you expect 6? We still have 5, so no new object was created!

If we stop and think about what we've learned so far though, this should make sense. Git stores the file by writing it to a path based on the file content hash. Since the content is identical, git writes to the same location, so there's no duplicated version of the file.

Now let's commit and look at the new objects.
```bash
$ git commit -m "Adds more comment files"
[master 7c8f6c1] Adds more comment files
 2 files changed, 4 insertions(+)
 create mode 100644 another-comment-copy.txt
 create mode 100644 another-comment.txt

$ ruby cat-objects.rb
Object: .git/objects/0a/44c4a16f8ffc20b657409872a46030991382c4
Hash: 0a44c4a16f8ffc20b657409872a46030991382c4
Type: blob
No seriously, Clojure is really fun!
Clojure is great!!!

Object: .git/objects/56/cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
Hash: 56cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
Type: tree
100644 blob d65a67c2695f0252b4dd846ca20a60ee9dc1f981	comments.txt

Object: .git/objects/5e/06553fe36d4faf161cebbb263b07f354379735
Hash: 5e06553fe36d4faf161cebbb263b07f354379735
Type: blob
No seriously, Clojure is really fun!

Object: .git/objects/7c/8f6c12a080d136516634f9f76534a7dc291a54
Hash: 7c8f6c12a080d136516634f9f76534a7dc291a54
Type: commit
tree af1f9760ba183aafa6dddff77d98d68be03102cd
parent a814d2d48078dffe11d661456c1062ad9e6bad96
author Jesse Hill <jessebhill@gmail.com> 1472484323 -0400
committer Jesse Hill <jessebhill@gmail.com> 1472484323 -0400

Adds more comment files

Object: .git/objects/a8/14d2d48078dffe11d661456c1062ad9e6bad96
Hash: a814d2d48078dffe11d661456c1062ad9e6bad96
Type: commit
tree 56cb5ecac8e9e2844133c526ae2ef9b7f7b191a5
author Jesse Hill <jessebhill@gmail.com> 1472482925 -0400
committer Jesse Hill <jessebhill@gmail.com> 1472482925 -0400

Adds comments file

Object: .git/objects/af/1f9760ba183aafa6dddff77d98d68be03102cd
Hash: af1f9760ba183aafa6dddff77d98d68be03102cd
Type: tree
100644 blob 0a44c4a16f8ffc20b657409872a46030991382c4	another-comment-copy.txt
100644 blob 0a44c4a16f8ffc20b657409872a46030991382c4	another-comment.txt
100644 blob d65a67c2695f0252b4dd846ca20a60ee9dc1f981	comments.txt

Object: .git/objects/d6/5a67c2695f0252b4dd846ca20a60ee9dc1f981
Hash: d65a67c2695f0252b4dd846ca20a60ee9dc1f981
Type: blob
It's fun to write Clojure code.
```
If you've followed the steps so far, you should have a tree object with the **af1f** hash like the one shown above. As we might have expected - the tree points to the same object hash for both new files even though the file names are different.

### Nested Trees
Ok, let's move our copied file to a sub-directory, add it, and commit:
```bash
$ mkdir copies
$ mv another-comment-copy.txt copies
$ git add copies
$ git write-tree
f5df18cb5709b6259b505825b60d50e008b5a9ee
```
Using the hash printed out by **git write-tree** we can inspect our repository's new root dir:
```bash
$ git cat-file -p f5df
100644 blob 0a44c4a16f8ffc20b657409872a46030991382c4	another-comment-copy.txt
100644 blob 0a44c4a16f8ffc20b657409872a46030991382c4	another-comment.txt
100644 blob d65a67c2695f0252b4dd846ca20a60ee9dc1f981	comments.txt
040000 tree 4d1a9b3cf659a6e2cdc3d66fe9cbef944c03cc61	copies
```
And we can use the **4d1a** hash listed to view our new directory tree: 
```bash
$ git cat-file -p 4d1a
100644 blob 0a44c4a16f8ffc20b657409872a46030991382c4	another-comment-copy.txt
```
So as you can see, the tree object is really more of a node object. And a tree can reference other trees. One important thing to note here is that a commit references the tree that represents the root directory and so from a commit we know the state of the entire working directory.

### Tag Objects
Let's celebrate our success so far by tagging our work:
```bash
$ git tag -a v1.0 -m "Our first version"
```
We can see our tag in the tags directory (not the objects directory!).
```bash
$ ls .git/refs/tags/
v1.0
```
What's in the file? (Note that again, due to timestamps, your hash will vary)
```bash
$ cat .git/refs/tags/v1.0
d0cf7f0c87fea8f38069fda6ebcad5f9e616848b
```
Ok. What if we use cat-file on that hash?
```bash
$ git cat-file -p d0cf
object d0308ae582a30751457b05f6450eeb898fe960a7
type commit
tag v1.0
tagger Jesse Hill <jessebhill@gmail.com> 1471471562 -0400

Our first version
```
Cool! And if we check the objects directory, we will see that our tag is just another object living in our objects directory.

## Working with Tags

There are many ways to refer to commits, so let's explore this area a little bit. Let's say your history looks something like this:
```bash
$ git log
commit 7c8f6c12a080d136516634f9f76534a7dc291a54
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Mon Aug 29 11:25:23 2016 -0400

    Adds more comment files

commit a814d2d48078dffe11d661456c1062ad9e6bad96
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Mon Aug 29 11:02:05 2016 -0400

    Adds comments file
```
You can deduce from the log that the tip of master is the commit **7c8f**. We can confirm that hash by inspecting the information in our .git directory.
```bash
$ cat .git/HEAD
ref: refs/heads/master
$ cat .git/refs/heads/master
7c8f6c12a080d136516634f9f76534a7dc291a54
```
There is however a simpler way. We can use rev-parse:
```bash
$ git rev-parse HEAD
7c8f6c12a080d136516634f9f76534a7dc291a54
```
And yep, it matches. Rev-parse is a helpful tool for learning how to use tag references:
```bash
$ git rev-parse HEAD~1
a814d2d48078dffe11d661456c1062ad9e6bad96
$ git rev-parse HEAD^1
a814d2d48078dffe11d661456c1062ad9e6bad96
$ git rev-parse HEAD@{15.minutes.ago}
git rev-parse HEAD@{15.minutes.ago}
$ git rev-parse HEAD@{yesterday}
warning: Log for 'HEAD' only goes back to Wed, 17 Aug 2016 17:43:12 -0400.
git rev-parse HEAD@{15.minutes.ago}
```
Cool. So if you're wondering what the difference is between **HEAD~2** and **HEAD^2**, rev-parse can help you out. Note also that git can find commits based on time ago (watch out for spaces - you'll need to quote things like "HEAD@{15 minutes ago}" or use appropriate separator characters (periods work, but there are other options).

You can also of course use it to inspect the hashes for branches.
```bash
$ git rev-parse master
7c8f6c12a080d136516634f9f76534a7dc291a54
```
## Rewriting History
>Rewriting history is a dangerous thing to do for any commits that have been shared with others. The reason is that all methods for rewriting history create new commmits, and can remove references to pushed commits. Folks working with those commits may find themselves in a strange state after pulling your code. So do be careful.

### Amending Commits
Ok, let's start with a clean repository and add a commit:
```bash
$ cd .. && rm -rf temp-repo && mkdir temp-repo && cd temp-repo && git init
$ echo "This workshop - seriously, amazing." >> comment.txt
$ git add .
$ git commit -m "Adds comment file"
[master (root-commit) 3174da9] Adds comment file
 1 file changed, 1 insertion(+)
 create mode 100644 comment.txt
```
Ok great. But now I'm feeling like maybe we should tone it down a little? Let's edit the file (I used vim) to say this instead:
>This workshop - it's not bad.

Next let's stage it:
```bash
$ git add comment.txt
```
Now, normally we might just commit, but if we want folks to think we're humble and that we aren't getting overly excited, it'd be nice if the previous commit were to "go away". So let's amend that previous commit instead:
```bash
$ git commit --amend -m "Edited comment file"
[master b0a69ff] Edited comment file
 Date: Wed Sep 21 19:52:22 2016 -0400
 1 file changed, 1 insertion(+)
 create mode 100644 comment.txt
```
And now if we check our log, even though we've run *git commit* twice, we will see just one commit and our history looks clean.
```bash
$ git log
commit e6f5dbe006a1800604859f60918eb407923c6315
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:34:52 2016 -0400

    Adds comment file
```
This is a feature you might find yourself using frequently. We often forget to add a file, we regret a comment, or we find linting errors or something of that sort. Amending let's us eliminate the "noise" commits that come from fixing these trivial errors.

>Note - If you run the *ruby cat-objects.rb* script, you'll see that we actually do still have our initial commit in our objects directory. The --amend writes a new commit - as it must since the referenced tree has changed as well as the timestamps - and points our history at that. So we do have two commits, but folks will see them as a single commit in the history.

### Interactive Rebasing
Let's add a couple more commits.
```bash
$ echo "This is a reasonable message" >> reasonable-1.txt
$ git add reasonable-1.txt && git commit -m "Reasonable message"
[master d620e25] Reasonable message
 1 file changed, 1 insertion(+)
 create mode 100644 reasonable-1.txt
$ echo "Woah, crazy town" >> crazy.txt
$ git add crazy.txt && git commit -m "Really losing it here"
[master 83501d0] Really losing it here
 1 file changed, 1 insertion(+)
 create mode 100644 crazy.txt
$ echo "This is another reasonable message" >> reasonable-2.txt
$ git add reasonable-2.txt && git commit -m "Another reasonable meessage"
[master 57445bc] Another reasonable meessage
 1 file changed, 2 insertions(+)
 create mode 100644 reasonable-2.txt
```
Ok, so now our history looks something like:
```bash
$ git log
commit 57445bca7e92fe8849b69435b144ab36252ce8b0
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:43:54 2016 -0400

    Another reasonable meessage

commit 83501d0fad9d3fb9c471f506120763b2d93bd227
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:42:10 2016 -0400

    Really losing it here

commit d620e254b5c28ed27729b5cd8feb7ac6539f9605
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:41:08 2016 -0400

    Reasonable message

commit e6f5dbe006a1800604859f60918eb407923c6315
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:34:52 2016 -0400

    Adds comment file
```
Maybe that second commit isn't so good. Let's rebase to get rid of it:
```bash
$ git rebase --interactive HEAD~3
```
We're telling git that we want to do an interactive rebase and we're giving it a reference to a commit to start the rebase from. It's important to pick a commit far enough back to include the changes we want to modify. It's ok if you go a little too far back. You should see something like:
```bash
  1 pick d620e25 Reasonable message
  2 pick 83501d0 Really losing it here
  3 pick 57445bc Another reasonable meessage
  4
  5 # Rebase e6f5dbe..57445bc onto e6f5dbe (3 command(s))
  6 #
  7 # Commands:
  8 # p, pick = use commit
  9 # r, reword = use commit, but edit the commit message
 10 # e, edit = use commit, but stop for amending
 11 # s, squash = use commit, but meld into previous commit
 12 # f, fixup = like "squash", but discard this commit's log message
 13 # x, exec = run command (the rest of the line) using shell
 14 #
 15 # These lines can be re-ordered; they are executed from top to bottom.
 16 #
 17 # If you remove a line here THAT COMMIT WILL BE LOST.
 18 #
 19 # However, if you remove everything, the rebase will be aborted.
 20 #
 21 # Note that empty commits are commented out
```
Let's just delete that second line, then save and exit.

Check your history:
```bash
$ git log
commit 0854128ec3e6536827c267934a67b5d36a4d98bd
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:43:54 2016 -0400

    Another reasonable meessage

commit d620e254b5c28ed27729b5cd8feb7ac6539f9605
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:41:08 2016 -0400

    Reasonable message

commit e6f5dbe006a1800604859f60918eb407923c6315
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Wed Aug 17 18:34:52 2016 -0400

    Adds comment file
```
And voila, we're back to being reasonable developers. You can use the other commands here to combine commits, split commits, change messages on commits, etc.

>One interesting thing to note is that the hash for the first commit (d620 here) does not change but the hash for commit 5744 has. This is of course because commits include the reference to their parent and for the second commit, the parent has changed. This should help explain why rebasing causes trouble for folks who already have your commits - the commits aren't simply moved - the old commits are no longer referenced and new commits take their place as needed.

I'd recommend creating some more commits here and playing around with the various options.

## Reset

Ok, let's talk about git reset. We have 3 modes - soft, hard, and mixed. What do these things mean again? And which mode do we want?

Well, we know that git has a staging area - we have to add files to this staging area before we can create a commit. This staging area is called the *index*. So, at any time, we have three interesting views of the contents of your repository:

- the HEAD commit, the last committed state
- the index - or the staged state of your directory
- the working directory - the actual current contents

We've seen that objects are created for your content when you add a file to the staging area, so if we've made a mistake, git can restore either a committed version of a file or the contents of the staging area.

Once again, let's start with a clean repository and add a commit:
```bash
$ cd .. && rm -rf temp-repo && mkdir temp-repo && cd temp-repo && git init
$ echo "I'm ready to reset some changes." >> thoughts.txt
$ git add . && git commit -m "Adds thoughts file"
[master (root-commit) fe307de] Adds thoughts file
 1 file changed, 1 insertion(+)
 create mode 100644 thoughts.txt
```
Then let's say we make this huge mistake:
```bash
$ echo "I really want to spend some time with php this week" >> thoughts.txt
```
We can see that we have files in our working directory that are not in the index:
```bash
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   thoughts.txt

no changes added to commit (use "git add" and/or "git commit -a")
```
To restore the file, we can simply check it out again:
```bash
$ git checkout -- thoughts.txt
```
And now we're back to where we were. 
>Note - the content was not added to the index and so it's not in our objects directory. It's gone forever.

What if we'd added the file to the index?
```bash
$ echo "I really want to spend some time with php this week" >> thoughts.txt
$ git add thoughts.txt
$ git status
On branch master
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

	modified:   thoughts.txt
```
Now we have two options. We can do a mixed reset (the default):
```bash
$ git reset HEAD
Unstaged changes after reset:
M	thoughts.txt
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   thoughts.txt

no changes added to commit (use "git add" and/or "git commit -a")
```
At this point, the index has been reset to look like the HEAD commit but our directory contents remain unchanged. 

We can also do a hard reset:
```bash
$ git reset --hard HEAD
HEAD is now at fe307de Adds thoughts file
$ git status
On branch master
nothing to commit, working directory clean
```
So now our file contents have been blown away. In this case though, we DID add the file to the index. So the blob should be out there somewhere. Let's see if we can find it:
```bash
$ git fsck
Checking object directories: 100% (256/256), done.
dangling blob 62af7c2b59a7abbaac32e774433d8c7a2c7860f5
```
Ok, that looks like it could be it.
```bash
$ git cat-file -p 62af
I'm ready to reset some changes.
I really want to spend some time with php this week
```
Sure enough! That's it. We can recover it by doing:
```bash
$ git cat-file -p 62af > thoughts.txt
```
Then commit:
```bash
$ git add thoughts.txt && git commit -m "Dangerous thoughts"
[master 82f16c1] Dangerous thoughts
 1 file changed, 1 insertion(+)
```
Ok, so now we have this commit, and we're having regrets. Since it's the top commit, we could simply **-amend** it. But let's see what we can do with reset (amend actually does a reset under the covers for you). We'll go back to the previous commit
```bash
$ git reset --soft HEAD~1
$ git status
On branch master
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

	modified:   thoughts.txt
```
Ok! So the soft reset moved the HEAD to the commit we specified, but did not change the index. If we instead use the default mixed mode:
```bash
$ git reset HEAD
Unstaged changes after reset:
M	thoughts.txt
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   thoughts.txt

no changes added to commit (use "git add" and/or "git commit -a")
```
Then we reset the index to match the HEAD, but not the working directory. A hard reset resets all three:
```bash
$ git reset --hard HEAD
HEAD is now at fe307de Adds thoughts file
$ git status
On branch master
nothing to commit, working directory clean
```
What if we want to recover that lost commit now? Let's try git fsck again:
```bash
$ git fsck
Checking object directories: 100% (256/256), done.
```
Interesting, it's not listed as a dangling object. How do we find our lost commit? We can use the reflog:
```bash
$ git reflog
7eaf792 HEAD@{0}: reset: moving to HEAD~1
de785d9 HEAD@{1}: commit: Dangerous thoughts
7eaf792 HEAD@{2}: commit (initial): Adds thoughts file
```
Ok there it is. If we want to recover it, we have a couple options. One is that we could reset to point to that commit directly. But what if we've made additional commits since we parted ways? Let's try it.
```bash
$ echo "Moving along" >> thoughts.txt && git add . && git commit -m "New content"
[master a7eeaff] New content
 1 file changed, 1 insertion(+)
```
Ok, now we don't simply want to reset because we'll lose our shiny new commit. But we can check out the lost commit and merge it back in.
```bash
$ git reflog
98ce561 HEAD@{0}: commit: New content
7eaf792 HEAD@{1}: reset: moving to HEAD~1
de785d9 HEAD@{2}: commit: Dangerous thoughts
7eaf792 HEAD@{3}: commit (initial): Adds thoughts file
$ git branch lost-commit HEAD@{2}
$ git status
On branch master
nothing to commit, working directory clean
$ git merge lost-commit
Auto-merging thoughts.txt
CONFLICT (content): Merge conflict in thoughts.txt
Automatic merge failed; fix conflicts and then commit the result.
```
Ok, good, we have a conflict now since both commits edited the file.
```bash
$ cat thoughts.txt
I'm ready to reset some changes.
<<<<<<< HEAD
Moving along
=======
I really want to spend some time with php this week
>>>>>>> lost-commit
```
We can resolve the diff and commit to complete our recovery.

## Finding Commits
Let's start again with a clean repo and add some commits:
```bash
$ cd .. && rm -rf temp-repo && mkdir temp-repo && cd temp-repo && git init
$ echo "File 1" >> file-1.txt && git add . && git commit -m "file-1.txt"
$ echo "Another file" >> file-2.txt && git add . && git commit -m "A useless comment"
$ echo "Something about ZLib::Inflate" >> file-3.txt && git add . && git commit -m "Another useless comment"
$ echo "Something about ZLib::Deflate" >> file-4.txt && git add . && git commit -m "Yet another useless comment"
$ echo "Clojure is a lot of fun to write." >> thoughts.txt && git add . && git commit -m "Thoughts about coding"
$ echo "Elm looks pretty interesting" >> thoughts.txt && git add . && git commit -m "Thoughts about elm"
$ echo "Haskell was really enjoyable" >> thoughts.txt && git add . && git commit -m "Thoughts about Haskell"
$ echo "I need to learn some F#" >> thoughts.txt && git add . && git commit -m "Thoughts about F#"
```
Ok. Now let's say we want to know which commit added "file-1.txt", how would we figure that out? In this case, we could probably just look through our git log because we've made the change recently and the comment mentions our file by name.
### Blame
If it didn't, we could of course use git blame. That would tell us something like:
```bash
$ git blame file-1.txt
^da08c5b (Jesse Hill 2016-08-18 08:27:57 -0400 1) File 1
```

### Pickaxe
So we could use the hash from that line to identify the commit. Let's say though we wanted to know all the commits that dealt with some particular term, across all files. We can use the pickaxe:
```bash
$ git log -SZLib --pretty=oneline
ee6302a1a9fd368fc54a50db48bf37d350d5d332 Yet another useless comment
334619042b8804b7dca79a89891f82cfd155cebd Another useless comment
```
The -S option is referred to as the pickaxe and it searches for terms across commits. Be careful though the pickaxe looks for changes in the number of times the term is present. It will find both additions and deletions of the term. It won't however find commits where the number of additions and deletions is the same.

### Bisect
Ok, one last method - git bisect.

Let's say we decide that we shouldn't use ZLib::Inflate in our codebase. How do we find the commit that broke our branch? We can use git bisect, which basically let's us do a binary search on the state of the branch.

We start by telling git that we want to run bisect and that the current state is bad:
```bash
$ git bisect start
$ git bisect bad
```
Now we need to tell it when we were last in a good state. It's ok to err on the side of caution here. Let's pick our root commit:
```bash
$ git bisect good HEAD~7
Bisecting: 3 revisions left to test after this (roughly 2 steps)
[ee6302a1a9fd368fc54a50db48bf37d350d5d332] Yet another useless comment
```
So, what's happened is that git has checked out commit ee63 and put us into a detached HEAD state. We can confirm this (your hash will vary):
```bash
$ cat .git/HEAD
ee6302a1a9fd368fc54a50db48bf37d350d5d332
```
Ok, so we need to figure out if the current version is good or bad. In our case, we can just do:
```bash
$ grep Inflate *
file-3.txt:Something about ZLib::Inflate
```
To tell that it's bad. But you could build and run tests or whatever. So we'll tell git that it's bad:
```bash
$ git bisect bad
Bisecting: 0 revisions left to test after this (roughly 1 step)
[334619042b8804b7dca79a89891f82cfd155cebd] Another useless comment

$ grep Inflate *
file-3.txt:Something about ZLib::Inflate
```
Still bad.
```bash
$ git bisect bad
Bisecting: 0 revisions left to test after this (roughly 0 steps)
[3c318a17679c779ce2ed053cd92ee84b91eb75ff] A useless comment
$ grep Inflate *
```
And now we're at the good commit, prior to the Inflate getting added. Let's tell git that we like this commit.
```bash
$ git bisect good
334619042b8804b7dca79a89891f82cfd155cebd is the first bad commit
commit 334619042b8804b7dca79a89891f82cfd155cebd
Author: Jesse Hill <jessebhill@gmail.com>
Date:   Thu Aug 18 08:28:11 2016 -0400

    Another useless comment

:000000 100644 0000000000000000000000000000000000000000 022f3f518b36b3438911b81ce4410aae4a26fb4d A	file-3.txt
```
So there we are. **3346** introduces the badness. Be sure to use git bisect reset now to go back to our original location:
```bash
$ git bisect reset
Previous HEAD position was 3c318a1... A useless comment
Switched to branch 'master'
```

## Git Hooks
Git hooks are local to your clone and not distributed with the repo. You might be tempted to use hooks to run tests or something of that sort before allowing a push. Resist this temptation, use hooks only for non-critical tasks that run very quickly. Or use them to confuse your colleague. Let's do that:
```bash
$ cd .git/hooks/
$ cp pre-commit.sample pre-commit
```
Edit the pre-commit file to look like:
```bash
  1 echo "No commits for you!"
  2 exit 1
```
Now save and exit. You may need to make the file executable, if it isn't already. Then try a commit:
```bash
$ echo "Howdy" >> hello.txt && git add . && git commit -m "Greetings"
No commits for you!
```
And you should see in your log that you have no new commit. Refer to the [hooks doc](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) for more info on hooks.

## Objects and Pack Files
Let's start once again with a clean repo and add a commit:
```bash
$ cd .. && rm -rf temp-repo && mkdir temp-repo && cd temp-repo && git init
$ echo "Howdy" >> hello.txt && git add . && git commit -m "Greetings"
```
Now let's take a look at our objects:
```bash
$ tree .git/objects
.git/objects
├── a5
│   └── c5dd0fc6c313159a69b1d19d7f61a9f978e8f1
├── d1
│   └── 2a3f36e0b24b4bb9bc3eafc3a89c8fe5eb63cd
├── fc
│   └── 483adb161ee8ae96d44267ab1ef169e40d25f8
├── info
└── pack
```
Let's try something here:
```bash
$ git gc
Counting objects: 3, done.
Writing objects: 100% (3/3), done.
Total 3 (delta 0), reused 0 (delta 0)
```
And take a look again:
```bash
$ tree .git/objects
.git/objects
├── info
│   └── packs
└── pack
    ├── pack-f2264fa89b541c2b6ef46022b1c7e9aec0d3d2fe.idx
    └── pack-f2264fa89b541c2b6ef46022b1c7e9aec0d3d2fe.pack

2 directories, 3 files
```
Woah, that's interesting. We have pack files now instead of objects. I expect the **git gc** output will look familiar to you, you've likely seen it when running other commands like git push. Git normally runs this on it's own at appropriate times to keep the repository size down.

The objects we've seen up to this point are called "loose objects" - they've been zipped versions of a file's content. With small files, this is no big deal, but you can imagine that having lots of versions of very large files would be a problem. **git gc** packs the loose objects into pack files. Pack files store the full contents of the file once and then deltas from the file for the other versions.


Let's try one more thing:
```bash
$ echo "Howdy there" >> hello.txt && git add .
$ git reset --hard
HEAD is now at d12a3f3 Greetings
$ git fsck
Checking object directories: 100% (256/256), done.
Checking objects: 100% (3/3), done.
dangling blob 9779c2e528757246e39f36e25bbc7162553f453f
$ git gc
Counting objects: 3, done.
Writing objects: 100% (3/3), done.
Total 3 (delta 0), reused 3 (delta 0)
$ git fsck
Checking object directories: 100% (256/256), done.
Checking objects: 100% (3/3), done.
dangling blob 9779c2e528757246e39f36e25bbc7162553f453f
$ tree .git/objects
.git/objects
├── 97
│   └── 79c2e528757246e39f36e25bbc7162553f453f
├── info
│   └── packs
└── pack
    ├── pack-f2264fa89b541c2b6ef46022b1c7e9aec0d3d2fe.idx
    └── pack-f2264fa89b541c2b6ef46022b1c7e9aec0d3d2fe.pack

3 directories, 4 files
```
So that's interesting. **git gc** didn't remove the dangling blob. It turns out **git gc** only prunes objects older than a given threshold. See the [git gc doc](https://git-scm.com/docs/git-gc) for configuration options.

Let's try one more thing:
```bash
$ git gc --prune=all
Counting objects: 3, done.
Writing objects: 100% (3/3), done.
Total 3 (delta 0), reused 3 (delta 0)
$ git fsck
Checking object directories: 100% (256/256), done.
Checking objects: 100% (3/3), done.
```
And now the dangling blob has been pruned. It's gone forever!
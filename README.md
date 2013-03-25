PushButton Networking for Monkey
================================

Original PushButton Networking: https://github.com/bgarde/PBNetworking 

Overview
--------

PushButton Networking for Monkey provides a powerful networking capabilities for
Monkey games.

It provides an efficient networking library, components to easily integrate with
your game, and a server uses the same code base as a client so you can run
identical game code on client and server. 

Features
--------

   * Write high performance networked Monkey games fast!
   * Run the same Monkey game code on server and client. 
   * Encodes messages with bit-level efficiency. (TODO Brl.DataBuffer is not talking nicely BitStream.)
   * Communicate with events.
   * Keep simulated objects synchronized with most-recent state updates.
   * Define your networking protocol using simple XML.
   * Brings the best practices of AAA C++ game networking to Monkey (TODO there are for loop in HTML5 and Java =P, can't be good especially these two uses virtual machine)
   * It is now multiplatform - HTML5 (client only), Flash (client only), GLFW, XNA, iOS, and Android.   

Getting Started
---------------

1. Copy the content of src, that is directory "pbnet/" into the Modules directory.
2. In the demo directory, build/run pbnetworkingserver.monkey
3. In the demo directory, build/run pbnetworkingdemo.monkey
4. Type "connect" at the pbnetworkingdemo prompt.

What is where?
--------------

The PBNetworking/ folder contains the core PushButton Networking library code 
(in src/), as well as documentation (in Documentation/) <-- docs TODO!

The demo/ folder has an example game demonstrating PBNetworking. You
can compile pbnetwrokingserver.monkey and pbnetworkingdemo.monkey, to run the demo.

The testNetworking/ folder has simple applications which run all the unit
tests that come with the networking library.

Support
-------

Contact me Ferdi on our forums for support.

http://www.monkeycoder.co.nz/Community/_index_.php

Or email me, my email address is at.

http://www.monkeycoder.co.nz/Account/showuser.php?id=414

Credits
-------

Original PushButton Networking by: 
   Timothy Aste,
   Ben Garney,
   Rick Overman,
   Sean Sullivan, and
   Jeff Tunnell  

PushButton Networking for Monkey Port by: Ferdinand Alexander, and Sascha Schmidt (Rone)
      
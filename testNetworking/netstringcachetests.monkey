
Strict

Import pbnet
Import utils

Function Main:Int()

	Print "2. Net String Cache Test"

	TestNetStringCache()

	Return 0

End Function

Function TestNetStringCache:Void()
	
	'Make quite a large BitStream as we'll be writing loads of data.
	Local bs:BitStream = New BitStream(1024*1024)

	'First, let's test that writing a single string multiple times
	'is working correctly.
		Local nsc:NetStringCache = New NetStringCache()

		For Local i:Int = 0 Until 4096
			nsc.Write(bs, "hello world how are you?");
		End For
            
		'At this time, the bitstream should be approximately
		'10bits * 4096 long (plus overhead For the first time,
		'when we encode the String). If we hit 8192 bytes we
		'have Not operated properly, as that's 16bits per entry
		'And we should only be using 10 plus a little bit on
		'average.
		AssertTrue(bs.CurrentPosition() < 8192*8);
            
		'Ok, great - now let's read back.
		bs.Reset();
		For Local i:Int = 0 Until 4096
			AssertEquals(nsc.Read(bs), "hello world how are you?");
		End For

		nsc.ReportStatistics()

	'Reset the BS so we can do another test.
	bs.Reset();
         
	'Great - now let's force it to purge stuff, so we can confirm
	'that A) the LRU logic isn't totally broken and B) we're meeting
	'our expectations on bit usage.

		nsc = New NetStringCache();

		'Write two thousand unique values, Then quite a few of the same thing
		For Local i:Int = 0 Until 2048
			nsc.Write(bs, "#" + i)
		End For
            
		For Local i:Int = 0 Until 4096
			nsc.Write(bs, "i am long but I will be cached as I am always the same.");
		End For
            
		'We should see a fairly low size of the String.
		'Working conservatively, we should have 
		'4095*2 + 2049 * (2 + 4)  = 20484 bytes in the stream.
		AssertTrue(bs.CurrentPosition() < 20484*8);
            
		'Do the readback.
		bs.Reset();
            
		For Local i:Int = 0 Until 2048
			AssertEquals(nsc.Read(bs), "#" + i);
		End For
            
		For Local i:Int = 0 Until 4096
			AssertEquals(nsc.Read(bs), "i am long but I will be cached as I am always the same.");
		End For
		
		nsc.ReportStatistics()

End Function

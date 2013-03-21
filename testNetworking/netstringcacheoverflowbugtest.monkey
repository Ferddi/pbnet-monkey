
Strict

Import pbnet
Import utils

Function Main:Int()

	Print "5. Net String Cache Overflow Bug Test"
	
	TestNetStringOverflow()
	
	Return 0

End Function

' TestCase for a previous bug in which net NetStringCache would be changed while errors occured
' during writing a cached string 

Function TestNetStringOverflow:Void()

	' Init a bitstream with 10 bytes
	Local bs:BitStream = New BitStream(10);
	bs.StringCache(New NetStringCache())

	' Fill up the bitstream with flags
	For Local i:Int = 0 Until 60
		bs.WriteFlag(True);
	End For

	'DebugStop()

	' Write a string that does not fit into the bitstream
	Local errorThrown:Bool = False

	Print "Write a string that does not fit into the bitstream, and EOFError will be thrown"

	Try

		bs.StringCache().Write(bs, "test")

	Catch e:EOFError
	
		Print "EOFError thrown: " + e.str
		errorThrown = True
	
	Catch e:NetError

		Print "NetError thrown"

	End Try

	' Check if an error was thrown
	Print "errorThrown should be True and it is " + ToString(errorThrown)
	AssertTrue(errorThrown)

	' Reset the bitstream to the start
	bs.Reset()

	' Write the same string again
	Print "Write the same string again"
	bs.StringCache().Write(bs, "test")

	' Reset to start
	bs.Reset()

	' Read the flag. It should be true, indicating a new string since the previous write failed
	Local readFlag:Bool = bs.ReadFlag()
	Print "Reset to the start and when we read should be True, and it is " + ToString(readFlag)
	Print "A True indicates a new string since the previous write failed"
	AssertTrue(readFlag)

End Function

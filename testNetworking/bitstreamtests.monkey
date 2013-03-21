
Strict

Import pbnet
Import utils

Function Main:Int()

	Print "1. Bit Stream Tests"

	TestReadBit()
	TestReadByte()
	TestReadWriteBits()
	TestReadWriteBytes()
	TestMixedReadWrite()
	TestStringReadWrite()
	TestRangedReadWrite()
	TestFloatReadWrite()
	TestIntReadWrite()
	
	Return 0

End Function

Function TestReadBit:Void()

	Local data:Int[] = [1, -128]
	Local bs:BitStream = New BitStream(data)
	
	Print "First bit we read should be true!"
	Print "First Bit: " + Int(bs.ReadFlag())
	Print "Next 14 Bits should be false."
	For Local i:Int = 0 Until 14
		Print i + " Bit: " + Int(bs.ReadFlag())
	End For
	Print "IsEof: " + Int(bs.IsEof())
	Print "Last bit we read should be true!"
	Print "Last Bit: " + Int(bs.ReadFlag())
	Print "We should be EOS after reading all 16 bits we put in."
	Print "IsEof: " + Int(bs.IsEof())
		
End Function
         
Function TestReadByte:Void()

	Local data:Int[] = [34, 209]
	
	Local bs:BitStream = New BitStream(data)
	
	Print "Byte 1 should be 34, and it is " + bs.ReadByte()
	Print "Byte 2 should be 209, and it is " + bs.ReadByte()
	Print "IsEof: " + Int(bs.IsEof())	 

End Function

Function TestReadWriteBits:Void()

	Local bs:BitStream = New BitStream(1)
	
	bs.WriteFlag(True)
	bs.WriteFlag(False)
	bs.WriteFlag(True)
	bs.WriteFlag(True)
	
	bs.Reset()
	
	Print "First Bit is true, and it is " + Int(bs.ReadFlag())
	Print "Second Bit is false, and it is " + Int(bs.ReadFlag())
	Print "Third Bit is true, and it is " + Int(bs.ReadFlag())
	Print "Fourth Bit is true, and it is " + Int(bs.ReadFlag())

End Function

Function TestReadWriteBytes:Void()

	Local bs:BitStream = New BitStream(4)
	
	bs.WriteByte($DE)
	bs.WriteByte($AD)
	bs.WriteByte($BA)
	bs.WriteByte($BE)
	
	bs.Reset()
	
	Print "First byte is " + $DE + ", and it is " + bs.ReadByte()
	Print "Second byte is " + $AD + " and it is " + bs.ReadByte()
	Print "Third byte is " + $BA + " and it is " + bs.ReadByte()
	Print "Fourth byte is " + $BE + ", and it is " + bs.ReadByte()
	
	Print "IsEof: " + Int(bs.IsEof())

End Function
         
Function TestMixedReadWrite:Void()

	Local bs:BitStream = New BitStream(5)
	
	bs.WriteFlag(True)
	bs.WriteByte($AB)
	bs.WriteByte($CD)
	bs.WriteFlag(False)
	bs.WriteByte($EF)
	bs.WriteByte($00)
	bs.WriteFlag(True)
	
	bs.Reset()
	
	Print "First bit should be true, and it is " + Int(bs.ReadFlag())
	Print "First byte is " + $AB + ", and it is " + bs.ReadByte()
	Print "Second byte is " + $CD + " and it is " + bs.ReadByte()
	Print "Middle bit should be false, and it is " + Int(bs.ReadFlag())
	Print "Third byte is " + $EF + " and it is " + bs.ReadByte()
	Print "Fourth byte is " + $00 + ", and it is " + bs.ReadByte()
	Print "Last bit should be true, and it is " + Int(bs.ReadFlag())

End Function

Function TestStringReadWrite:Void()

	Local test1:String = "Hey there I am a string"
	Local test2:String = "Another string"
	
	Local bs:BitStream = New BitStream(64)
	
	bs.WriteString(test1)
	bs.WriteFlag(True)
	bs.WriteFlag(False)
	bs.WriteString(test2)
	bs.WriteByte(23)
	
	bs.Reset()
	
	Print test1 + " = " + bs.ReadString()
	Print "This bit should be true, and it is " + Int(bs.ReadFlag())
	Print "This bit should be false, and it is " + Int(bs.ReadFlag())
	Print test2 + " = " + bs.ReadString()
	Print "This byte should be 23, and it is " + bs.ReadByte()

End Function            
         
Function TestRangedReadWrite:Void()

	Local test1:String = "Hey there I am a string"
	Local test2:String = "Another string"
	
	Local bs:BitStream = New BitStream(64)
	
	bs.WriteRangedInt(5,  5, 25)
	bs.WriteRangedInt(10, 5, 25)
	bs.WriteRangedInt(25, 5, 25)
         
	bs.WriteRangedInt(0,    0, 1024)
	bs.WriteRangedInt(512,  0, 1024)
	bs.WriteRangedInt(1023, 0, 1024)
   
	bs.Reset()
	
	Print "The correct number is 5, and it is " + bs.ReadRangedInt(5, 25)
	Print "The correct number is 10, and it is " + bs.ReadRangedInt(5, 25)
	Print "The correct number is 25, and it is " + bs.ReadRangedInt(5, 25)
         
	Print "The correct number is 0, and it is " + bs.ReadRangedInt(0, 1024)
	Print "The correct number is 512, and it is " + bs.ReadRangedInt(0, 1024)
	Print "The correct number is 1023, and it is " + bs.ReadRangedInt(0, 1024)

End Function

Function TestIntReadWrite:Void()

	Local bs:BitStream = New BitStream(128)
    
	#rem
    Print "$7FFFFFFF = " + $7FFFFFFF
         
	bs.Reset()
	bs.WriteInt(0, 32)
	bs.WriteInt(-1, 32)
	bs.WriteInt(-2, 32)
	bs.WriteInt($7FFFFFFF, 32)
	bs.WriteInt($80000000, 32)
	bs.Reset()
	AssertEquals(bs.ReadInt(32), 0)
	AssertEquals(bs.ReadInt(32), -1)
	AssertEquals(bs.ReadInt(32), -2)
	AssertEquals(bs.ReadInt(32), $7FFFFFFF)
	AssertEquals(bs.ReadInt(32), $80000000)
	#End
	

	'Test smaller bit counts by checking every value.
	'Here we check everything from 1 to 8 bits.
	For Local curCount:Int = 0 To 8

		Local maxVal:Int = (1 Shl curCount) - 1

		For Local curVal:Int = 1 To maxVal

			'Write some test data.
			bs.Reset()
			bs.WriteFlag(True)
			bs.WriteFlag(False)
			bs.WriteInt(curVal, curCount)
			bs.WriteByte($13)
               
			'Read it back.
			bs.Reset()
			AssertTrue(bs.ReadFlag())
			AssertFalse(bs.ReadFlag())
			AssertEquals(bs.ReadInt(curCount), curVal)
			AssertEquals(bs.ReadByte(), $13)

		End For

	End For
	         
	'For higher bit counts, we run a hundred random numbers through each count.
	For Local curCount:Int = 9 To 32

		Local maxVal:Int = (1 Shl curCount) - 1
		If curCount = 31 Then
			maxVal = $7FFFFFFF
		End If
		
		Print "curCount: " + curCount
		Print "maxVal: " + maxVal

		For Local trial:Int = 0 Until 100

			'Generate a random value.
			Local randVal:Int = Int(Rnd() * maxVal)
			'Print "randVal: " + randVal
               
			'Write the data out. We also write zero And max To be sure they
			'encode ok.
			bs.Reset()
			bs.WriteByte($FF)
			bs.WriteInt(randVal, curCount)
			bs.WriteInt(0, curCount)
			bs.WriteInt(maxVal, curCount)
			bs.WriteFlag(True)
               
			'And read it back...
			bs.Reset()
			AssertEquals(bs.ReadByte(), $FF)
			AssertEquals(bs.ReadInt(curCount), randVal)
			AssertEquals(bs.ReadInt(curCount), 0)
			AssertEquals(bs.ReadInt(curCount), maxVal)
			AssertTrue(bs.ReadFlag())
			
		End For

	End For
	
End Function

Function TestFloatReadWrite:Void()

	Local bs:BitStream = New BitStream(128)
         
	'Determining the exact decimation that will occur is hard, so
	'instead we'll estimate acceptable error and fail if we exceed
	'that.
	'
	'(Note: simply duplicating the decimation that happens in the
	'writeFloat isn't a suitable test; we need an independent test.)
         
	For Local bitCount:Int = 2 To 30

		'Figure the acceptable error at this bit count.
		Local acceptableError:Float = 1.0 / Float(((1 Shl bitCount)-1))
            
		'We choose a hundred random numbers, encode, decode, and validate them.
		For Local i:Int = 0 Until 100
			Local randNum:Float = Rnd() 'Random number from 0 .. 1
               
			bs.Reset()
			bs.WriteFloat(randNum, bitCount)
   
			bs.Reset()
			Local result:Float = bs.ReadFloat(bitCount)
   
			If Abs(randNum - result) > acceptableError Then
				Print "FAIL - Exceeded acceptable error (randNum=" + randNum + ", result=" + result +
                      ", error=" + Abs(randNum - result) + ", acceptableError=" + acceptableError
			End If
		End For
	End For
	
	Print "Finish Float test"

End Function

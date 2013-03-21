
Strict

Import pbnet

'Class to perform bit-level reads and writes.
Class BitStream
    
    Const BYTE_LENGTH:Int = 8
    
    Field bits:Int[]
	Field currentBit:Int = 0
	Field totalBits:Int = 0
	Field _stringCache:NetStringCache

	'Constructor with an array of data	
	Method New(data:Int[])
	
		bits = bits.Resize(data.Length)
		totalBits = data.Length * BYTE_LENGTH
		Reset()
		
		For Local i:Int = 0 Until data.Length
		
			bits[i] = data[i]
		
		End For
	
	End Method

	'Constructor with just the size of data
	Method New(length:Int)
	
		bits = bits.Resize(length)
		totalBits = length * BYTE_LENGTH
		Reset()
		
		For Local i:Int = 0 Until length
		
			bits[i] = 0
		
		End For
	
	End Method
	
	'Write a bit to the stream and advance to the next bit.
	Method WriteFlag:Bool(value:Bool)
	
		If currentBit >= totalBits Then
			Throw New EOFError("Out of bits!")
		End If
		
		If value = True Then
			bits[(currentBit Shr 3)] |= (1 Shl (currentBit & 7))
		Else
			bits[(currentBit Shr 3)] &= ~(1 Shl (currentBit & 7))
		End If
		
		currentBit += 1
		
		Return value

	End Method

	'Read a bit from the stream and advance to the next bit.
	Method ReadFlag:Bool()
	
		If currentBit >= totalBits Then
			Throw New EOFError("Out of bits!")
		End If
		
		Local b:Int = bits[(currentBit Shr 3)]
		
		b Shr= (currentBit & 7)
		currentBit += 1
		b &= 1
		
		If b = 1 Then
			Return True
		End If
		
		Return False
	
	End Method

	'Write an 8-bit byte to the stream.
    Method WriteByte:Void(value:Int)
    
    	WriteInt(value, BYTE_LENGTH)
    
    End Method

	'Read an 8-bit byte from the stream.
	Method ReadByte:Int()
	
		Return ReadInt(BYTE_LENGTH)
		
	End Method		
	
	'Write a signed Int with the specified number of bits.
    '<p>The value written must range from 0..2**bitCount. value
    'is treated as If it is masked against (2**bitCount - 1).</p>	
    Method WriteInt:Void(value:Int, bitCount:Int)
    
    	If bitCount < 32 Then
    		If value < 0 Then
    			Throw New NetError("When bitCount is 31 bits or below, WriteInt can only write positive number")
    		End If
    	End If
    
    	For Local i:Int = 0 Until bitCount
    	
    		If ((value Shr i) & 1) = 1 Then
	    		WriteFlag(True)
    		Else		
    			WriteFlag(False)
    		End If
    	
    	End For
    
    End Method

	'Read a signed int with the specified number of bits.
	'@see writeInt
	Method ReadInt:Int(bitCount:Int)
	
		Local b:Int = 0
		
		For Local i:Int = 0 Until bitCount
		
			b |= (Int(ReadFlag()) Shl i)
		
		End For
		
		Return b
		
	End Method
	
	'Write a UTF8 string.
	'<p>The format is a 10 bit length specified in bytes, followed by that many
	'bytes encoding the String in UTF8.</p>
	Method WriteString:Void(s:String)
	
		WriteInt(s.Length, 10)
		For Local i:Int = 0 Until s.Length
			WriteByte(s[i])
		End For
	
	End Method
	
	'Read a string from the bitstream.
	'@see writeString()
	Method ReadString:String()

		Local lenInBytes:Int = ReadInt(10)
		Local ints:Int[] = New Int[lenInBytes]

		For Local i:Int = 0 Until lenInBytes
			ints[i] = ReadByte()
		End For
		
		Return String.FromChars(ints)
	
	End Method

	'Get number of bits required to encode values from 0..max.
	'@param max The maximum value To be able To be encoded.
	'@Return Bitcount required To encode max value.
	Method GetBitCountForRange:Int(max:Int)

		Local count:Int = 0
		
		'Unfortunately this is a bug with this method... and requires this special
		'case (same issue with the old method log calculation)
		If max = 1 Then
			Return 1
		End If
			
		max -= 1
		While (max Shr count > 0)
			count += 1
		End While
		
		Return count

	End Method
	
	'Write an integer value that can range from min to max inclusive. Calculates
	'required number of bits automatically. 
	Method WriteRangedInt:Void(v:Int, min:Int, max:Int) 
	
		Local range:Int = max - min + 1
		Local bitCount:Int = GetBitCountForRange(range)
	
		WriteInt(v - min, bitCount)
	
	End Method
	
	'Read an integer that can range from min To max inclusive. Calculates required
	'number of bits automatically.
	Method ReadRangedInt:Int(min:Int, max:Int) 
	
		Local range:Int = max - min + 1
		Local bitCount:Int = GetBitCountForRange(range)
	
		Local res:Int = ReadInt(bitCount) + min
		
		If res < min Then
            Throw New NetError("Read int that was below range! (" + res + " < " + min + ")")
		Else If res > max Then
            Throw New NetError("Read int that was above range! (" + res + " > " + max + ")")
		End If
		
		Return res		
	
	End Method

	'Write a float ranging from 0..1 inclusive encoded into the specified number
	'of bits.
	Method WriteFloat:Void(value:Float, bitCount:Int)
	
		If value >= 0.0 And value <= 1.0 Then
			'Good everything is fine as long as the float is 0..1 inclusive	
			WriteInt(Int(value * ((1 Shl bitCount) - 1)), bitCount)
		Else
   			Throw New NetError("WriteFloat can only write value from 0..1 inclusive.")
    	End If
    	
	End Method
	
	'Read a float ranged from 0 to 1 inclusive encoded into the specified number of bits.
	Method ReadFloat:Float(bitCount:Int)
	
		Return Float(ReadInt(bitCount)) / Float((1 Shl bitCount) - 1)
	
	End Method

	Method IsEof:Bool()
	
		If currentBit >= totalBits Then
			Return True
		End If
		
		Return False
	
	End Method
	
	Method Reset:Void()
	
		currentBit = 0
	
	End Method

	'Position in the bit stream at which the next read or write will occur.
	'Reading or writing increments this position.
	Method CurrentPosition:Int()

		Return currentBit

	End Method
      
	Method CurrentPosition:Void(pos:Int)

		If pos < 0 Or pos >= totalBits Then
			Throw New NetError("Out of bounds!")
		End If
         
		currentBit = pos

	End Method
      
	'How many bits of space left?
	Method RemainingBits:Int()
         Return totalBits - currentBit
	End Method
      
	'Get a reference To a ByteArray containing this BitStream's data.
	Method GetByteArray:Int[]()
         Return bits
	End Method
      
	'Convenience Property To allow a NetStringCache To be associated with a
	'BitStream; the BitStream doesn't use it itself.
	Method StringCache:Void(sc:NetStringCache)
		_stringCache = sc
	End Method
      
	Method StringCache:NetStringCache()
		Return _stringCache
	End Method
      
	'Read a byte, check that it has the expected value, And Throw an exception with message If it does Not.
	Method AssertByte:Void(message:String, expectedByte:Int)
		Print "Checking assertion byte at " + CurrentPosition()
         
		Local b:Int = ReadByte()
		If b <> expectedByte Then
			Throw New NetError("Mismatch: " + message + " (" + b + " != " + expectedByte + ")")
		End If
	End Method

End Class

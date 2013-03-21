
Strict

Import pbnet

Class ByteArray

	Field position:Int
	Field bytesAvailable:Int
	Field length:Int
	Field data:Int[]
	
	Method New(dataLength:Int)
	
		data = New Int[dataLength]
		position = 0
		bytesAvailable = 0
		length = 0
	
	End Method
	
	Method WriteShort:Void(value:Int)
	
		data[position] = (value Shr 8) & $FF
		position += 1
		data[position] = value & $FF
		position += 1
		
		BytesAvailable()
	
	End Method
	
	Method ReadShort:Int()

		Local value:Int = 0
	
		value = (data[position] Shl 8)
		position += 1
		value += (data[position])
		position += 1

		BytesAvailable()
		
		Return value
	
	End Method
	
	Method WriteByte:Void(value:Int)
	
		data[position] = value
		position += 1
		
		BytesAvailable()
	
	End Method
	
	Method ReadByte:Int()
	
		Local value:Int = 0
		
		value = data[position]
		
		BytesAvailable()
		
		Return value
	
	End Method
	
	Method WriteBytes:Void(bytes:Int[], len:Int)
	
		For Local i:Int = 0 Until len
		
			data[position] = bytes[i]
			position += 1
		
		End For
		
		BytesAvailable()
		
	End Method
	
	Method ReadBytes:Void(bytes:Int[], len:Int)
	
		For Local i:Int = 0 Until len
		
			bytes[i] = data[position]
			position += 1
		
		End For
		
		BytesAvailable()

	End Method
	
	Method BytesAvailable:Int()

		If length <= position Then
			length = position
		End If
	
		bytesAvailable = length - position
		Return bytesAvailable
	
	End Method

End Class

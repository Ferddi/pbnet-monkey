
Strict

Function ToHex:String(i:Int)

	''p=32-bit
	Local r%=i, s%, p%=32, n:Int[p/4+1]

	While (p>0)
		
		s = (r&$f)+48
		If s>57 Then s+=7
		
		p-=4
		n[p Shr 2] = s
		r = r Shr 4
		 
	Wend

	Return String.FromChars(n)
	
End

Function Lsr:Int(val:Int, shift:Int)
	
	Return (val Shr shift) & ((1 Shl (32 - shift)) - 1)

End Function

Function Rol:Int(val:Int, shift:Int)

	Return (val Shl shift) | Lsr(val, (32 - shift))

End Function

' Converts a String To a sequence of 16-word blocks
' that we'll do the processing on.  Appends padding
' And length in the process.
'
' @param s The String To split into blocks
' @Return An Array containing the blocks that s was
'                      split into.

Function CreateBlocks:Int[]( s:String )

	Local len:Int = s.Length * 8
	Local blockLen:Int = ( ( ( len + 64 ) Shr 9 ) Shl 4 ) + 15 + 1
	Local blocks:Int[] = New Int[blockLen]
	Local mask:Int = $FF ' ignore hi byte of characters > 0xFF
	Local chars:Int[] = s.ToChars()

	For Local i:Int = 0 Until len Step 8
		blocks[ (i Shr 5) ] |= ( chars[ (i / 8) ] & mask ) Shl (24 - i Mod 32)
	End For

	' append padding And length
	blocks[ len Shr 5 ] |= $80 Shl ( 24 - len Mod 32 )
	blocks[ ( ( ( len + 64 ) Shr 9 ) Shl 4 ) + 15 ] = len

	'Local blockLen:Int = ( ( ( len + 64 ) Shr 9 ) Shl 4 ) + 15
	'Print "Len: " + len
	'Print "block length: " + blockLen

	Return blocks

End Function

' Performs the logical Function based on t
Function f:Int( t:Int, b:Int, c:Int, d:Int )

	If t < 20 Then
		Return ( b & c ) | ( ~b & d )
	Else If t < 40 Then
		Return b ~ c ~ d
	Else If t < 60 Then
		Return ( b & c ) | ( b & d ) | ( c & d )
	End If

	Return b ~ c ~ d

End Function
                
' Determines the constant value based on t
Function k:Int( t:Int )

	If t < 20 Then
		Return $5a827999
	Else If ( t < 40 )
		'DebugStop()
		Return $6ed9eba1
	Else If ( t < 60 )
		Return $8f1bbcdc
	End If

	Return $ca62c1d6

End Function

Function Sha1:Int[]( s:String )

	'DebugStop()

	' initialize the h's
	Local h:Int[5]
	h[0] = $67452301
	h[1] = $efcdab89
	h[2] = $98badcfe
	h[3] = $10325476
	h[4] = $c3d2e1f0
                        
	' create the blocks from the String And
	' save the length as a Local var To reduce
	' lookup in the loop below
	Local blocks:Int[] = CreateBlocks( s )
	Local len:Int = blocks.Length;

	Local w:Int[] = New Int[ 80 ]

	' loop over all of the blocks
	For Local i:Int = 0 Until len Step 16 
                        
		' 6.1.c
		Local a:Int = h[0]
		Local b:Int = h[1]
		Local c:Int = h[2]
		Local d:Int = h[3]
		Local e:Int = h[4]

		' 80 steps To process each block
		' TODO: unroll For faster execution, Or 4 loops of
		' 20 each To avoid the k And f Function calls
		For Local t:Int = 0 Until 80

			If t < 16 Then
				' 6.1.a
				'DebugStop()
				w[ t ] = blocks[ i + t ]
			Else
				'DebugStop()
				' 6.1.b
				w[ t ] = Rol( w[ t - 3 ] ~ w[ t - 8 ] ~ w[ t - 14 ] ~ w[ t - 16 ], 1 )
			End If

			' 6.1.d
			Local r:Int = Rol( a, 5 )
			Local f:Int = f( t, b, c, d )
			Local wt:Int = w[ t ]
			Local k:Int = k(t)
			Local temp:Int = r +  f + e + wt + k
                                        
			'DebugStop()

			e = d
			d = c
			c = Rol( b, 30 )
			b = a
			a = temp

		End For

		' 6.1.e
		h[0] += a
		h[1] += b
		h[2] += c
		h[3] += d
		h[4] += e

	End For

	Local res:Int[20]
	Local j:Int = 0
	
	For Local i:Int = 0 Until 20 Step 4
	
		res[i + 0] = (h[j] Shr 24) & $FF
		res[i + 1] = (h[j] Shr 16) & $FF
		res[i + 2] = (h[j] Shr  8) & $FF
		res[i + 3] =  h[j]         & $FF
		
		j += 1
	
	End For

	'For Local i:Int = 0 Until 20
	'	Print "Res: " + ToHex(res[i])
	'End For
	
	Return res

End Function

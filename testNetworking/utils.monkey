
Strict

Function ToString:String(b:Bool)

	If b = False Then
		Return "False"
	End If
	
	Return "True"

End Function

Function AssertTrue:Void(b:Bool)

	If b = False Then
		Print "FAIL - should be True!"
	End If

End Function

Function AssertTrue:Void(s:String, b:Bool)

	Print s
	AssertTrue(b)

End Function

Function AssertFalse:Void(b:Bool)

	If b = True Then
		Print "FAIL - should be False!"
	End If

End Function

Function AssertEquals:Void(v1:Int, v2:Int)

	If v1 <> v2 Then
		Print "FAIL - value is not the same! v1 = " + v1 + " <> v2 = " + v2
	End If

End Function

Function AssertEquals:Void(v1:String, v2:String)

	If v1 <> v2 Then
		Print "FAIL - value is not the same! v1 = " + v1 + " <> v2 = " + v2
	End If

End Function

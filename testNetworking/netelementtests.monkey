
Strict

#REFLECTION_FILTER="pbnet.elements.*"
Import reflection

Import pbnet
Import utils

Function Main:Int()

	Print "3. Net Element Test"

	TestNetElements()
	TestFlagElement()
	TestXML()
	TestDirtyFlags()
	
	Return 0

End Function

Function TestNetElements:Void()

	' Set up the serialization structure.
	Local nr:NetRoot = New NetRoot();
	nr.AddElement(New StringElement("chatText", "hey there world"));
	nr.AddElement(New FloatElement("chatVolume", 14, 0.90001));
         
	' Write out To a stream. 
	Local bs:BitStream = New BitStream(64);
   
	Try
		nr.Serialize(bs);         
	Catch e:EOFError
		Error e.ToString()
	End Try   
         
	' Change values.
	nr.SetString("chatText", "filler");
	nr.SetFloat("chatVolume", 0.0);
         
	' Read back.
	bs.Reset();
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' Validate results.
	Print "chatText: " + nr.GetString("chatText")
	AssertEquals(nr.GetString("chatText"), "hey there world");
         
	Local floatVal:Float = nr.GetFloat("chatVolume");
	Print "Abs: " + Abs(floatVal - 0.90001)
	If Abs(floatVal - 0.90001) > 0.01
		Error "Did not get back our expected float."
	End If

End Function

      
Function TestFlagElement:Void()

	' Set up serialization 
	Local nr:NetRoot = New NetRoot();
	nr.AddElement(New FlagElement("flag", True));
	nr.AddElement(New StringElement("string2", "end"));

	Local fe:FlagElement = FlagElement(nr.GetElement("flag"));
	fe.AddElement(New StringElement("string", "hey there"));
         
	' Blast some permutations out To a BitStream.
	Local bs:BitStream = New BitStream(256);
         
	' Write with flag set To True...
	Try
		nr.Serialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try
         
	' Write it with flag set To False.
	nr.SetBoolean("flag", False);

	Try
		nr.Serialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' Ok, now read back the first one.
	bs.Reset();
         
	nr.SetString("string2", "bad");
	nr.SetString("string", "bad2");
         
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try
         
	' Both strings should change in this Case...
	AssertEquals(nr.GetString("string2"), "end");
	AssertTrue(nr.GetBoolean("flag"));
	AssertEquals(nr.GetString("string"), "hey there");

	' Set more state To garbage...
	nr.SetString("string2", "bad");
	nr.SetString("string", "bad2");
         
	' Now, read back the second one.
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' And check state...
	AssertEquals(nr.GetString("string2"), "end");
	AssertFalse(nr.GetBoolean("flag"));
	AssertEquals(nr.GetString("string"), "bad2");

End Function

Function TestXML:Void()

	Local eventXML:String = "" +
		"<library>" +
		"	<event>" +
		"		<name>chat</name>" +
		"		<string>" +
		"			<name>message</name>" +
		"		<string>" +	
		"	</event>" +
		"	<event>" +
		"		<name>circle</name>" +
		"		<rangedInt>" +
		"			<name>x</name>" +
		"			<min>0</min>" +
		"			<max>1000</max>" +
		"		</rangedInt>" +
		"		<rangedInt>" +
		"			<name>y</name>" +
		"			<min>0</min>" +
		"			<max>1000</max>" +
		"		</rangedInt>" +
		"	</event>" +
		"	<ghost>" +
		"		<name>CircleGhost</name>" +
		"		<dirtyFlag>" +
		"			<name>flag1</name>" +
		"			<rangedInt>" +
		"				<name>x</name>" +
		"				<min>0</min>" +
		"				<max>1000</max>" +
		"			</rangedInt>" +
		"			<rangedInt>" +
		"				<name>y</name>" +
		"				<min>0</min>" +
		"				<max>1000</max>" +
		"			</rangedInt>" +
		"			<flag>" +
		"				<name>state</name>" +
		"			</flag>" +
		"		</dirtyFlag>" +
		"	</ghost>" +
		"</library>"
	'NetRoot.loadNetProtocol(eventXML)

	Local testXml:String = "" +
		"<root>" + 
		"	<string>" + 
		"		<name>stringItem</name>" +
		"	</string>" +
		"	<float>" +
		"		<name>floatItem</name>" +
		"		<bitCount>8</bitCount>" +
		"	</float>" +
		"	<flag>" +
		"		<name>flagItem</name>" +
		"		<float>" +
		"			<name>floatItem2</name>" +
		"			<bitCount>16</bitCount>" +
		"		</float>" +
		"	</flag>" +
		"</root>"

	'DebugStop()

	' Note we test the deep copy here as well.
	Local netRoot:NetRoot = New NetRoot(testXml)
	Local nr:NetRoot = NetRoot(netRoot.DeepCopy())
         
	' Make sure elements are of correct types And their properties are right.
	Local cinfo:ClassInfo
	Local floatElement:FloatElement
	
	cinfo = GetClass(nr.GetElement("stringItem"))
	Print "cinfo.Name for stringItem is StringElement = " + cinfo.Name
	cinfo = GetClass(nr.GetElement("floatItem"))
	Print "cinfo.Name for floatItem is FloatElement = " + cinfo.Name
	floatElement = FloatElement(nr.GetElement("floatItem"))
	Print "floatElement.bitCount is 8 = " + floatElement.bitCount
         
	cinfo = GetClass(nr.GetElement("floatItem2"))
	Print "cinfo.Name for floatItem2 is FloatElement = " + cinfo.Name
	floatElement = FloatElement(nr.GetElement("floatItem2"))
	Print "floatElement.bitCount is 16 = " + floatElement.bitCount

End Function

Function TestDirtyFlags:Void()

	Local testXml:String =	"" +
		"<root>" +
		"	<dirtyFlag>" +
		"		<name>dirty01</name>" +
		"		<string>" +
		"			<name>stringField1</name>" +
		"		</string>" +
		"		<float>" +
		"			<name>floatItem</name>" +
		"			<bitCount>8</bitCount>" +
		"		</float>" +
		"	</dirtyFlag>" +
		"	<dirtyFlag>" +
		"		<name>dirty02</name>" +
		"		<float>" +
		"			<name>floatItem2</name>" +
		"			<bitCount>16</bitCount>" +
		"		</float>" +
		"		<dirtyFlag>" +
		"			<name>dirty03</name>" +
		"			<string>" +
		"				<name>stringField2</name>" +
		"			</string>" +
		"		</dirtyFlag>" +
		"	</dirtyFlag>" +
		"</root>"
                     
	' Note we test the deep copy here as well.
	Local netRoot:NetRoot = New NetRoot(testXml)
	Local nr:NetRoot = NetRoot(netRoot.DeepCopy())
         
	' Ok, let's check the dirty bits for each element. In reality, we do not assume what bits
	' get assigned where, since it's for internal tracking only.
	'Print "stringField1 dirty bit is 1 = " + nr.GetElementDirtyBits("stringField1")
	'Print "floatItem dirty bit is 1 = " + nr.GetElementDirtyBits("floatItem")
	'Print "floatItem2 dirty bit is 2 = " + nr.GetElementDirtyBits("floatItem2")
	'Print "stringField2 dirty bit is 6 = " + nr.GetElementDirtyBits("stringField2")
	AssertEquals(nr.GetElementDirtyBits("stringField1"), $1);
	AssertEquals(nr.GetElementDirtyBits("floatItem"), $1);
	AssertEquals(nr.GetElementDirtyBits("floatItem2"), $2);
	AssertEquals(nr.GetElementDirtyBits("stringField2"), $2 | $4);
         
	' Test getting elemeny by id.
	'Print "Dirty Bit 0 name is dirty01 = " + nr.GetDirtyBitElement(0).GetName()
	'Print "Dirty Bit 1 name is dirty02 = " + nr.GetDirtyBitElement(1).GetName()
	'Print "Dirty Bit 2 name is dirty03 = " + nr.GetDirtyBitElement(2).GetName()
	AssertEquals(nr.GetDirtyBitElement(0).GetName(), "dirty01");
	AssertEquals(nr.GetDirtyBitElement(1).GetName(), "dirty02");
	AssertEquals(nr.GetDirtyBitElement(2).GetName(), "dirty03");

	' Set some dirty states And check that the dirty flags are set properly.
	nr.SetDirtyState($0);
	AssertEquals(nr.GetBoolean("dirty01"), False);
	AssertEquals(nr.GetBoolean("dirty02"), False);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), False);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1 | $2);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1 | $2 | $4);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), True);
         
	nr.SetDirtyState($2 | $4);
	AssertEquals(nr.GetBoolean("dirty01"), False);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), True);

End Function

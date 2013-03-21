
Strict

#REFLECTION_FILTER="testevents|pbnet.elements.*|pbnet.events.*"
Import reflection

Import pbnet
Import utils
Import testevents

Function Main:Int()

	Print "4. Event Tests"
	
	TestFullDuplexEventTransfer()

	Return 0

End Function

' Test sending and receiving events via in-memory buffers.
Function TestFullDuplexEventTransfer:Void()

	' Give the library a test event.
	'var libraryXML:XML =
	'<protocol>
	'   <event name="TestEvent">
	'      <rangedInt name="counter" min="0" max="1024"/>
	'      <String name="payload"/>
	'      <flag name="fromServer"/>
	'   </event>
	'</protocol>;

	Local libraryXML:String =
	"<protocol>" +
	"	<event>" +
	"		<name>TestEvent</name>" +
	"		<rangedInt>" +
	"			<name>counter</name>" +
	"			<min>0</min>" +
	"			<max>1024</max>" +
	"		</rangedInt>" +
	"		<string>" +
	"			<name>payload</name>" +
	"		</string>" +
	"		<flag>" +
	"			<name>fromServer</name>" +
	"		</flag>" +
	"	</event>" +
	"</protocol>"
         
    'DebugStop()
   
	Local netRoot:NetRoot = New NetRoot()
	netRoot.LoadNetProtocol(libraryXML)

	Local testEvent:TestEvent = New TestEvent()

	Local netEvent:NetEvent = New NetEvent()
	netEvent.SetNetRoot(netRoot)
	netEvent.RegisterClass("TestEvent", testEvent)
         
	'TestEvent.CurrentTestCase = Self
	LastClientIndex = -1
	LastServerIndex = -1
         
	' Create connections To simulate client And server.
	Local ecServer:EventConnection = New EventConnection(netEvent)
	Local ecClient:EventConnection = New EventConnection(netEvent)

	' Queue up enough events on both connections that it will take several packets To transfer them.
	For Local i:Int=0 Until 1024

		' Produce an event with some filler content And a counter so we can validate it works
		' correctly. Also note direction so we can be sure we're not getting mixed up.

		' Server -> client event.
		ecServer.PostEvent(New TestEvent(netRoot, True, i))

		' Client -> server event.
		ecServer.PostEvent(New TestEvent(netRoot, False, i))

	End For

	' Great. Now write And read packets And make sure the events make it through.

	' Sanity check: If we are taking close To 1 packet/event we are in trouble.
	Local safetyCount:Int = 4000

	Local serverToClientBuffer:ByteArray = ByteArray(1024)
	Local clientToServerBuffer:ByteArray = ByteArray(1024)

	'DebugStop()

	While ecServer.HasDataPending() Or ecClient.HasDataPending()

		' Make sure our buffer pointers are right.
		serverToClientBuffer.position = 0
		clientToServerBuffer.position = 0

		' Have the connections write packets into buffers.
		ecServer.SendPacketToBuffer(serverToClientBuffer)
		ecClient.SendPacketToBuffer(clientToServerBuffer)
            
		' Make sure our buffer pointers are right.
		serverToClientBuffer.position = 0
		clientToServerBuffer.position = 0

		' And now have them read!
		ecServer.ReadPacketsFromBuffer(clientToServerBuffer)
		ecClient.ReadPacketsFromBuffer(serverToClientBuffer)

		' Update safety net.
		safetyCount -= 1
		If safetyCount <= 0
			' We ran too long.
			Error "Took too many packets to send our data!"
			Exit
		End If

	End While

	' Ok, make sure the right number of things made it over.
	AssertEquals(LastClientIndex, 1023)
	AssertEquals(LastServerIndex, 1023)

End Function

Function FailFromEvent:Void(msg:String)

	Error "Event failed us for: " + msg

End Function

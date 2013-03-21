
Import mojo
Import diddy
Import reflection


'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------

' The template manager loads And unloads level files And stores information
' about their contents. The Serializer is used To deserialize Object
' descriptions.
'
' <p>A level file can contain templates, entities, And groups. A template
' describes an entity that will be instantiated several times, like a
' bullet. Templates are left unnamed when they are instantiated.</p>
'
' <p>An entity describes a complete entity that is only instantiated once, like
' a background tilemap. Entities are named based on the name of the xml data
' that describes it.</p>
'
' <p>A group contains references To templates, entities, And other groups that
' should be instantiated when the group is instantiated.</p>
'
' @see com.pblabs.engine.serialization.Serializer.
Class TemplateManager ' Extends EventDispatcher

	' Defines the event To dispatch when a level file is successfully loaded.
	Const LOADED_EVENT:String="LOADED_EVENT"

	' Defines the event To dispatch when a level file fails To load.
	Const FAILED_EVENT:String="FAILED_EVENT"

	' Report every time we create an entity.
	Field VERBOSE_LOGGING:Bool=False

	' Allow specifying an alternate Class To use For IEntity.
	'Method EntityType(value:Class):Void
	'	_entityType=value;
	'End Method

	' Loads a level file And adds its contents To the template manager. This
	' does Not instantiate any of the objects in the file, it merely loads
	' them For future instantiation.
	'
	' <p>When the load completes, the LOADED_EVENT will be dispatched. If
	' the load fails, the FAILED_EVENT will be dispatched.</p>
	'
	' @param filename The file To load.
	'Method LoadFile:Void(filename:String, forceReload:Boolean = False)
	'	PBE.resourceManager.load(filename, XMLResource, onLoaded, onFailed, forceReload);
	'End Method

	' Unloads a level file And removes its contents from the template manager.
	' This does Not destroy any entities that have been instantiated.
	'
	' @param filename The file To unload.
	'Method UnloadFile:Void(filename:String)
	'	RemoveXML(filename);
	'	PBE.resourceManager.unload(filename, XMLResource);
	'End Method

	' Creates an instance of an Object with the specified name. The name must
	' refer To a template Or entity. To instantiate groups, use instantiateGroup
	' instead.
	'
	' @param name The name of the entity Or template To instantiate. This
	' corresponds To the name attribute on the template Or entity tag in the XML.
	'
	' @param entityName optional name To instantiate the entity with If name refers To a template
	'
	' @Return The created entity, Or Null If it wasn't found.
	Method InstantiateEntity:IEntity(name:String, entityName:String = "")

		Local entity:IEntity = Null

		'Profiler.enter("instantiateEntity");

		Try

			Local tr:ThingReference = _things.Get(name)

			' Check For a callback.
			If tr

				If tr.groupCallback

					Throw New NetError("Thing '" + name + "' is a group callback!");

				End If

				If tr.entityCallback

					Print "TODO - No entity callback!"
					'Local instantiated:IEntity=tr.entityCallback.Main()
					'Profiler.Exit("instantiateEntity");
					'Return instantiated;

				End If

			End If

			Local xml:XMLElement = GetXML(name, "template", "entity");

			If Not xml

				Error "instantiateEntity - Unable to find a template or entity with the name " + name + "."
				'Profiler.Exit("instantiateEntity");
				Return Null

			End If

			entity = InstantiateEntityFromXML(xml, entityName);
			'Profiler.Exit("instantiateEntity");

		Catch e:NetError

			Error "instantiateEntity - Failed instantiating '" + name + "' due to: " + e.ToString() + "\n" ' + e.getStackTrace()
			entity = Null
			'Profiler.Exit("instantiateEntity")

		End Try

		Return entity

	End Method

	' Given an XML literal, construct a valid entity from it.
	' @param entityName optional name To instantiate the entity with If the xml is a template
	Method InstantiateEntityFromXML:IEntity(xml:XMLElement, entityName:String = "")

		'Profiler.enter("instantiateEntityFromXML");
#rem
		Try
		{
			' Get at the name...
			Local name:String = xml.attribute("name");
			If (xml.name() == "template")
					name = (entityName == Null) ? "" : entityName;

                // And the alias...
				var alias:String=xml.attribute("alias");
				If (alias == "")
					alias = Null;

                // Make the IEntity instance.
				var entity:IEntity;
				If (!_entityType)
					entity = allocateEntity();
				Else
					entity = New _entityType();

                // To aid with reference handling, initialize FIRST but defer the
                // reset...
                entity.initialize(name, alias);
                entity.deferring = True;
                
                If (!doInstantiateTemplate(entity, xml.attribute("template"), New Dictionary()))
				{
					entity.destroy();
					Profiler.Exit("instantiateEntityFromXML");
					Return Null;
				}

				Serializer.instance.deserialize(entity, xml);
				Serializer.instance.clearCurrentEntity();

                // Don't forget to disable deferring.
                entity.deferring = False;

				If (!_inGroup)
					Serializer.instance.reportMissingReferences();

				Profiler.Exit("instantiateEntityFromXML");
			}
			Catch (e:Error)
			{
				Logger.Error(this, "instantiateEntity", "Failed instantiating '" + name + "' due to: " + e.toString() + "\n" + e.getStackTrace());
				entity=Null;
				Profiler.Exit("instantiateEntityFromXML");
			}
			Return entity;
#End

		Return Null

	End Method
#rem
		/**
		 * instantiates all templates Or entities referenced by the specified group.
		 *
		 * @param name The name of the group To instantiate. This correspands To the
		 * name attribute on the group tag in the XML.
		 *
		 * @Return An Array containing all the instantiated objects. If the group
		 * wasn't found, the array will be empty.
		 */
		Public Function instantiateGroup(name:String):Array
		{
			// Check For a callback.
			If (_things[name])
			{
				If (_things[name].entityCallback)
					Throw New Error("Thing '" + name + "' is an entity callback!");
				
				// We won't dispatch the GROUP_LOADED event here as it's the callback
				// author's responsibility.
				If (_things[name].groupCallback)
					Return _things[name].groupCallback();
			}

			Try
			{
				var group:Array=New Array();
				If (!doInstantiateGroup(name, group, New Dictionary()))
				{
					For each (var entity:IEntity in group)
						entity.destroy();

					Return Null;
				}
				
				If(hasEventListener(TemplateEvent.GROUP_LOADED))
					dispatchEvent(New TemplateEvent(TemplateEvent.GROUP_LOADED, name));
					
				Return group;
			}
			Catch (e:Error)
			{
				Logger.Error(this, "instantiateGroup", "Failed to instantiate group '" + name + "' due to: " + e.toString());
				Return Null;
			}

			// Should never get here, one branch Or the other of the Try will take it.
			Throw New Error("Somehow skipped both branches of group instantiation try/catch block!");
			Return Null;
		}
#End

	' Adds an XML description of a template, entity, Or group To the template manager so
	' it can be instantiated in the future.
	'
	' @param xml The xml To add.
	' @param identifier A String by which this xml can be referenced. This is Not the
	' name of the Object. It is used so the xml can be removed by a call To RemoveXML.
	' @param version The version of the format of the added xml.
	Method AddXML:Void(xml:String, identifier:String, version:Int)

		Local name:String=xml.attribute("name");

		If name.length = 0
			Print "Warning - AddXML - XML object description added without a 'name' attribute."
			Return
		End If

		If _things[name]
			Print "Warning - AddXML - An XML object description with name " + name + " has already been added."
			Return
		End If

		Local thing:ThingReference=New ThingReference();
		thing.xmlData=xml;
		thing.identifier=identifier;
		thing.version=version;

		_things.Set(name, thing)

	End Method

	' Removes the specified Object from the template manager.
	'
	' @param identifier This is Not the name of the xml Object. It is the value
	' passed as the identifier in AddXML.
	Method RemoveXML:Void(identifier:String)

		Local thingsToDelete:List<String> = New List<String>()
		
		For Local name:String = Eachin _things.Keys
			Local thing:ThingReference = _things.Get(name)
			If thing.identifier = identifier
				thingsToDelete.AddLast(name)
			End If
		End For

		For Local name:String = Eachin thingsToDelete
			_things.Remove(name)
		End For

	End Method

	' Gets a previously added xml description that has the specified name.
	'
	' @param name The name of the xml To retrieve.
	' @param xmlType1 The type (template, entity, Or group) the xml must be.
	' If this is Null, it can be anything.
	' @param xmlType2 Another type (template, entity, Or group) the xml can
	' be.
	'
	' @Return The xml description with the specified name, Or Null If it wasn't
	' found.
	Method GetXML:XMLElement(name:String, xmlType1:String = "", xmlType2:String = "")

		Local thing:ThingReference=DoGetXML(name, xmlType1, xmlType2);

		If thing
			Return thing.xmlData
		End If
		
		Return Null

	End Method

#rem
		/**
		 * Check If a template Method by the provided name has been registered.
		 * @param name Name of the template registered with the TemplateManager
		 * @Return True If the template exists, False If it does Not.
		 */		
		Public Function hasEntityCallback(name:String):Boolean
		{
			Return _things[name];
		}
		
		/**
		 * Register a callback-powered entity with the TemplateManager. Instead of
		 * parsing And returning an entity based on XML, this lets you directly
		 * create the entity from a Function you specify.
		 *
		 * Generally, we recommend using XML For entity definitions, but this can
		 * be useful For reducing external dependencies, Or providing special
		 * functionality (For instance, a single name that returns several
		 * possible entities based on chance).
		 *
		 * @param name Name of the entity.
		 * @param callback A Function which takes no arguments And returns an IEntity.
		 * @see UnregisterEntityCallback, RegisterGroupCallback, hasEntityCallback
		 */
		Public Function registerEntityCallback(name:String, callback:Function):Void
		{
			If (callback == Null)
				Throw New Error("Must pass a callback function!");

			If (_things[name])
				Throw New Error("Already have a thing registered under '" + name + "'!");

			var newThing:ThingReference=New ThingReference();
			newThing.entityCallback=callback;
			_things[name]=newThing;
		}

		/**
		 * Unregister a callback-powered entity registered with RegisterEntityCallback.
		 * @see RegisterEntityCallback
		 */
		Public Function unregisterEntityCallback(name:String):Void
		{
			If (!_things[name])
			{
				Logger.warn(this, "unregisterEntityCallback", "No such template '" + name + "'!");
				Return;
			}

			If (!_things[name].entityCallback)
				Throw New Error("Thing '" + name + "' is not an entity callback!");

			_things[name]=Null;
			delete _things[name];
		}

		/**
		 * Register a Function as a group. When the group is requested via instantiateGroup,
		 * the Function is called, And the Array it returns is given To the user.
		 *
		 * @param name NAme of the group.
		 * @param callback A Function which takes no arguments And returns an Array of IEntity instances.
		 * @see UnregisterGroupCallback, RegisterEntityCallback
		 */
		Public Function registerGroupCallback(name:String, callback:Function):Void
		{
			If (callback == Null)
				Throw New Error("Must pass a callback function!");

			If (_things[name])
				Throw New Error("Already have a thing registered under '" + name + "'!");

			var newThing:ThingReference=New ThingReference();
			newThing.groupCallback=callback;
			_things[name]=newThing;
		}

		/**
		 * Unregister a Function-based group registered with RegisterGroupCallback.
		 * @param name Name passed To RegisterGroupCallback.
		 * @see RegisterGroupCallback
		 */
		Public Function unregisterGroupCallback(name:String):Void
		{
			If (!_things[name])
				Throw New Error("No such thing '" + name + "'!");

			If (!_things[name].groupCallback)
				Throw New Error("Thing '" + name + "' is not a group callback!");

			_things[name]=Null;
			delete _things[name];
		}
#End
		Method DoGetXML:ThingReference(name:String, xmlType1:String, xmlType2:String)

			Local thing:ThingReference = _things.Get(name)

			If Not thing
				Return Null
			End If

			' No XML on callbacks.
			If thing.entityCallback <> Null Or thing.groupCallback <> Null
				Return Null
			End If

			If xmlType1

				'Local type:String = thing.xmlData.name()
				Local type:String = thing.xmlData.GetFirstChildByName("name").Value.ToLower()

				If type <> xmlType1 And type <> xmlType2
					Return Null
				End If

			End If

			Return thing

		End Method
#rem
		Private Function doInstantiateTemplate(Object:IEntity, templateName:String, tree:Dictionary):Boolean
		{
			If (templateName == Null || templateName.length == 0)
				Return True;

			If (tree[templateName])
			{
				Logger.warn(this, "instantiateTemplate", "Cyclical template detected. " + templateName + " has already been instantiated.");
				Return False;
			}

			var templateXML:XML=getXML(templateName, "template");
			If (!templateXML)
			{
				Logger.warn(this, "instantiate", "Unable to find the template " + templateName + ".");
				Return False;
			}

			tree[templateName]=True;
			If (!doInstantiateTemplate(Object, templateXML.attribute("template"), tree))
				Return False;

			Object.deserialize(templateXML, False);

			Return True;
		}

		Private Function doInstantiateGroup(name:String, group:Array, tree:Dictionary):Boolean
		{
			var xml:XML=getXML(name, "group");
			If (!xml)
				Throw New Error("Could not find group '" + name + "'");
                
            //Create the group:
            var actualGroup:PBGroup = New PBGroup();
            If(name != PBE.rootGroup.name)
            {
                actualGroup.initialize(name);
                actualGroup.owningGroup = PBE.currentGroup;
            }
            Else
            {
                actualGroup = PBE.rootGroup;
            }

            var oldGroup:PBGroup = PBE.currentGroup;
            PBE.currentGroup = actualGroup;    
            
			For each (var objectXML:XML in xml.*)
			{
				var childName:String=objectXML.attribute("name");
				If (objectXML.name() == "groupReference")
				{
					If (tree[childName])
						Throw New Error("Cyclical group detected. " + childName + " has already been instantiated.");

					tree[childName]=True;

					// Don't need to check for return value, as it will throw an error 
					// If something bad happens.
					Try
					{
						If (!doInstantiateGroup(childName, group, tree))
							Return False;
					}
					Catch (err:*)
					{
						Logger.warn(this, "instantiateGroup", "Failed to instantiate group '" + childName + "' from groupReference in '" + name + "' due to: " + err);
						Return False;
					}
				}
				Else If (objectXML.name() == "objectReference")
				{
					_inGroup = True;
					group.push(instantiateEntity(childName));
					_inGroup=False;
				}
				Else
				{
					Logger.warn(this, "instantiateGroup", "Encountered unknown tag " + objectXML.name() + " in group.");
				}
			}
            
            PBE.currentGroup = oldGroup;

			Serializer.instance.reportMissingReferences();

			Return True;
		}

		Private Function onLoaded(resource:XMLResource):Void
		{
			var version:Int=resource.XMLData.attribute("version");
			var thingCount:Int=0;
			For each (var xml:XML in resource.XMLData.*)
			{
				thingCount++;
				addXML(xml, resource.filename, version);
			}

			Logger.Print(this, "Loaded " + thingCount + " from " + resource.filename);

			dispatchEvent(New Event(LOADED_EVENT));
		}

		Private Function onFailed(resource:XMLResource):Void
		{
			dispatchEvent(New Event(FAILED_EVENT));
		}

		Private var _inGroup:Boolean=False;
		Private var _entityType:Class=Null;
#End

	Field _things:StringMap<ThingReference> = New StringMap<ThingReference>()

End Class


'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------



'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------


' Provides an Interface For objects To override the Default serialization
' behavior.
' 
' <p>Any Class implementing this Interface will automatically have its
' serialize And deserialize methods called in place of the Default serialization
' methods on the Serializer Class.</p>
' 
' @see Serializer
' @see ../../../../../Examples/CustomSerialization.html Custom Serialization
Interface ISerializable

	' serializes the Object To XML. This should Not Include the main tag
	' defining the Class itself.
	' 
	' @param xml The xml Object To which the serialization of this Class should
	' be added. This xml Object is a single tag containing the main Class definition,
	' so only children of this Class should be added To it.
	' 
	' @see ../../../../../Examples/SerializingObjects.html Serializing Objects
	Method Serialize:Void(xml:String)
      
	' deserializes the Object from xml. The format of the xml passed is custom,
	' depending on the way the Object was serialized with the serialize Method.
	' 
	' @param xml The xml containing the serialized definition of the class.
	'
	' @return The deserialized object. Usually 'this' should be returned, but in
	' some cases it may be useful to return something else. The Enumerable class
	' does this to force all values to be a member of the enumeration.
	' 
	' @see ../../../../../Examples/DeserializingObjects.html Deserializing Objects
	Method Deserialize:Object(xml:String)

End Interface


   
' Set of PBObjects. A PBObject may be in many sets; sets do Not destroy
' their contained objects when they are destroyed. Sets automatically
' remove destroy()'ed objects. 
Class PBSet Extends PBObject

	Field items:List<PBObject> = New List<PBObject>()

	Method GetItem:PBObject(index:Int)

		If items = Null
			Return Null
		End If

		If index < 0 Or index >= items.Count()
			Return Null
		End If

		Local itemsArray:PBObject[] = items.ToArray()

		Return itemsArray[index]

	End Method
        
	Method Length:Int()
	
		If items
			Return items.Count()
		End If

		Return 0

	End Method
        
	Method Contains:Bool(item:PBObject)

		If items = Null
			Throw New NetError("Accessing destroy()'ed set.");
		End If

		Return items.Contains(item)

	End Method
        
	Method Add:Bool(item:PBObject)

		' Can't add ourselves to ourselves.
		If item = Self
			Return False
		End If
            
		If items = Null
			Throw New NetError("Accessing destroy()'ed set.")
		End If

		' Was the item present?
		If Contains(item)
			Return False
		End If
            
		' No, add it.
		item.NoteInSet(Self)
		items.AddLast(item)

		Return True

	End Method
        
	Method Remove:Bool(item:PBObject)

		' Can't remove ourselves from ourselves.
		If item = Self
			Return False
		End If
            
		If items = Null
			'Throw New NetError("Accessing destroy()'ed set.");
			Print "remove - Removed item from dead PBSet."
			item.NoteOutOfSet(Self);
			Return True
		End If

		' Is item present?
		'var idx:Int = items.indexOf(item);
		'If(idx == -1)
		'	Return False;
            
		' Yes, remove it.
		item.NoteOutOfSet(Self)
		'items.splice(idx, 1)
		Local result:Int = items.RemoveEach(item)
		
		If result = 0
			Return False
		End If

		Return True

	End Method
        
	' Destroy all the objects in this set, but do Not delete the set.
	Method Clear:Void()

		' Delete the items we own.
		While items.Count()
			Local pbObj:PBObject = items.RemoveFirst()
			pbObj.Destroy()
		End While

	End Method

	Method Destroy:Void() 

		If items = Null
			Throw New NetError("Accessing destroy()'ed set.");
		End If

		' Pass control up.
		Super.Destroy()

		' Clear out items.
		While items.Count()
			Local pbObj:PBObject = items.RemoveLast()
			Remove(pbObj)
		End While

		items = Null

	End Method

End Class

Global currentGroup:PBGroup = Null

' Base implementation of a named Object that can exist in PBSets Or PBGroups.
'
' @see IPBObject
Class PBObject Implements IPBObject

	Field _name:String
	Field _alias:String
	Field _owningGroup:PBGroup
	Field _sets:List<PBSet>

	Method NoteInSet:Void(s:PBSet)

		If Not _sets
			_sets = New List<PBSet>
		End If

		If _sets.Contains(s) = True
			Return
		End If

		_sets.AddLast(s)

	End Method

	Method NoteOutOfSet:Void(s:PBSet)

		'var idx:Int = _sets.indexOf(s);
		'If(idx == -1)
		'	Throw New Error("Removed object from set that it isn't in.");
		'_sets.splice(idx, 1);
		
		_sets.RemoveEach(s)

	End Method

	Method OwningGroup:PBGroup()

		Return _owningGroup;

	End Method

	Method OwningGroup:Void(value:PBGroup)

		If Not value
			Throw New NetError("Must always be in a group - cannot set owningGroup to null!");
		End If

		If _owningGroup
			_owningGroup.RemoveFromGroup(Self)
		End If

		_owningGroup = value
		_owningGroup.AddToGroup(Self)

	End Method

	Method Name:String()
		Return _name;
	End Method

	Method ObjAlias:String()
		Return _alias;
	End Method

	Method Initialize:Void(name:String = "", objAlias:String = "")

		' Note the names.
		_name = name;
		_alias = objAlias;

		' Register with the name manager.
		Print "Name manager is not working."
		'PBE.nameManager.add(this);

		' Put us in the current group If we have no group specified.
		If OwningGroup = Null And currentGroup <> Self
			OwningGroup(currentGroup);
		End If

	End Method

	Method Destroy:Void()

		' Remove from the name manager.
		Print "Name manager is not working."
		'PBE.nameManager.remove(this);

		' Remove from any sets.
		'While _sets And _sets.Count()

			' remove() cuts us from the list.
			' Note - if it returned false, we weren't in the set, so remove
			' set membership on our end. This is usually an artifact of
			' the set removing us from itself.
			'If(_sets[_sets.length-1].remove(this) == False)
			'	_sets.pop();

		'End While
		
		If _sets
		
			For Local pbSet:PBSet = Eachin _sets
			
				If pbSet.Remove(Self) = False
					_sets.RemoveEach(pbSet)
				End If
			
			End For
		
		End If

		' Remove from our owning group.
		If _owningGroup

			_owningGroup.RemoveFromGroup(Self)
			_owningGroup = Null

		End If

	End Method

	Method ChangeName:Void(name:String)

		If name
			' Remove from the name manager.
			Print "Name manager is not working."
			'PBE.nameManager.remove(this);

			' Change the name.
			_name = name;

			' Register with the name manager.
			Print "Name manager is not working."
			'PBE.nameManager.add(this);
		End If

	End Method

End Class

' A group which owns the objects contained it. When the PBGroup is
' deleted, it deletes its owned objects. Assign a PBObject To a PBGroup
' by setting Object.owningGroup.
Class PBGroup Extends PBObject

	Field items:List<IPBObject> = New List<IPBObject>
        
	Method AddToGroup:Bool(item:IPBObject)

		items.AddLast(item)
		Return True

	End Method

	Method RemoveFromGroup:Bool(item:IPBObject)

		'Local idx:Int = items.indexOf(item);
		'If(idx == -1)
		'	Return False;
		'items.splice(idx, 1);
		'Return True
		
		Local result:Int = items.RemoveEach(item)

		If result = 0
			Return False
		End If

		Return True
		
	End Method

	' Return the IPBObject at the specified index.
	Method GetItem:IPBObject(index:Int)

		If index < 0 Or index >= items.Count()
			Return Null
		End If
		
		Local itemsArray:IPBObject[] = items.ToArray()

		Return itemsArray[index];

	End Method
        
	' How many PBObjects are in this group?
	Method Length:Int()
		Return items.Count()
	End Method
        
	' Destroy all the objects in this group, but do Not delete the group.
	Method Clear:Void()
		' Delete the items we own.
		Print "Better check with a debugger whether this works"
		Local count:Int = items.Count()
		While count
			items.RemoveFirst()
			count = items.Count()
		End While
	End Method

	Method Destroy:Void()

		' Delete everything.
		Clear()

		' Pass control up.
		Super.Destroy()

	End Method

End Class




  





' Default implementation of IEntity.
'
' <p>Please use allocateEntity() to get at instances of Entity; this allows
' us to pool Entities at a later date if needed and do other tricks. Please
' program against IEntity, not Entity, to avoid dependencies.</p>
Class Entity Extends PBObject Implements IEntity

	Method Deferring:Bool()
		Return _deferring;
	End Method

	Method Deferring:Void(value:Bool)

		If _deferring = True And value = False

			Print "TODO - Deferring is not working"

			' Resolve everything, And everything that that resolution triggers.
			'Local needReset:Bool = False

			'If _deferredComponents.length > 0
			'	needReset = True
			'End If
			
			'While(_deferredComponents.length)
			'	Local pc:PendingComponent = _deferredComponents.shift() as PendingComponent;
			'	pc.item.register(this, pc.name);
			'End While

			' Mark deferring as done.
			'_deferring = False;

			' Fire off the reset.
			'If needReset
			'	DoResetComponents()
			'End If

		End If

		_deferring = value;

	End Method

#rem
        Public Function get eventDispatcher():IEventDispatcher
        {
            Return _eventDispatcher;
        }
#End

	Method Name:String()
		Return Super.Name()
	End Method

	Method ObjAlias:String()
		Return Super.ObjAlias()
	End Method

	Method OwningGroup:Void(value:PBGroup)
		Super.OwningGroup(value)
	End Method
	
	Method OwningGroup:PBGroup()
		Return Super.OwningGroup()
	End Method

	Method Initialize:Void(name:String = "", objAlias:String = "")
		' Pass control up.
		Super.Initialize(name, objAlias);

		' Resolve any pending components.
		Deferring(False)
	End Method

	' Destroys the Entity by removing all components And unregistering it from
	' the name manager.
	'
	' @see IPBObject.destroy
	Method Destroy:Void()
#rem
            // Give listeners a chance To act before we start destroying stuff.
            If(_eventDispatcher.hasEventListener("EntityDestroyed"))
                _eventDispatcher.dispatchEvent(New Event("EntityDestroyed"));

            // Unregister our components.
            For each(var component:IEntityComponent in _components)
            {
                If(component.isRegistered)
                    component.unregister();
            }

            // And remove their references from the dictionary.
            For (var name:String in _components)
                delete _components[name];

            // Get out of the NameManager And other general cleanup stuff.
            Super.destroy();
#End
	End Method

	' Serializes an entity. Pass in the current XML stream, And it automatically
	' adds itself To it.
	' @param	xml the <things> XML stream.
	Method Serialize:Void(xml:String)
#rem        
            var entityXML:XML = <entity name={name} />;
            If(alias!=Null)
                entityXML = <entity name={name} alias={alias} />;

            For each (var component:IEntityComponent in _components)
            {
                var componentXML:XML = <component type={getQualifiedClassName(component).replace(/::/,".")} name={component.name} />;
                Serializer.instance.serialize(component, componentXML);
                entityXML.appendChild(componentXML);
            }

            xml.appendChild(entityXML);
#End            
	End Method

	Method Deserialize:Void(xml:String, registerComponents:Bool = True)
#rem
		' Note what entity we're deserializing to the Serializer.
            Serializer.instance.setCurrentEntity(this);

            // Push the deferred state.
            var oldDefer:Boolean = deferring;
            deferring = True;

            // Process each component tag in the xml.
            For each (var componentXML:XML in xml.*)
            {
                // Error If it's an unexpected tag.
                If(componentXML.name().toString().toLowerCase() != "component")
                {
                    Logger.Error(this, "deserialize", "Found unexpected tag '" + componentXML.name().toString() + "', only <component/> is valid, ignoring tag. Error in entity '" + name + "'.");
                    Continue;
                }

                var componentName:String = componentXML.attribute("name");
                var componentClassName:String = componentXML.attribute("type");
                var component:IEntityComponent = Null;

                If (componentClassName.length > 0)
                {
                    // If it specifies a type, instantiate a component And add it.
                    component = TypeUtility.instantiate(componentClassName) as IEntityComponent;
                    If (!component)
                    {
                        Logger.Error(this, "deserialize", "Unable to instantiate component " + componentName + " of type " + componentClassName + " on entity '" + name + "'.");
                        Continue;
                    }

                    If (!addComponent(component, componentName))
                        Continue;
                }
                Else
                {
                    // Otherwise just get the existing one of that name.
                    component = lookupComponentByName(componentName);
                    If (!component)
                    {
                        Logger.Error(this, "deserialize", "No type specified for the component " + componentName + " and the component doesn't exist on a parent template for entity '" + name + "'.");
                        Continue;
                    }
                }

                // Deserialize the XML into the component.
                Serializer.instance.deserialize(component, componentXML);
            }

            // Deal with set membership.
            var setsAttr:String = xml.attribute("sets");
            If (setsAttr)
            {
                // The entity wants To be in some sets.
                var setNames:Array = setsAttr.split(",");
                If (setNames)
                {
                    // There's a valid-ish set string, let's loop through the entries
                    var thisName:String;
                    While (thisName = setNames.pop())
                    {
                        var pbset:PBSet = PBE.lookup(thisName) as PBSet;
                        If (!pbset)
                        {
                            // Set doesn't exist, create a new one.
                            pbset = New PBSet();
                            pbset.initialize(thisName);
                            Logger.warn(this, "deserialize", "Auto-creating set '" + thisName + "'.");
                        }
                        pbset.add(this as PBObject);
                    }
                }
            }

            // Restore deferred state.
            deferring = oldDefer;
#End
	End Method

	Method AddComponent:Bool(component:IEntityComponent, componentName:String)
#rem
            // Add it To the dictionary.
            If (!doAddComponent(component, componentName))
                Return False;

            // If we are deferring registration, put it on the list.
            If(deferring)
            {
                var p:PendingComponent = New PendingComponent();
                p.item = component;
                p.name = componentName;
                _deferredComponents.push(p);
                Return True;
            }

            // We have To be careful w.r.t. adding components from another component.
            component.register(this, componentName);

            // Fire off the reset.
            doResetComponents();
#End
            Return True;

	End Method

	Method RemoveComponent:Void(component:IEntityComponent)
#rem
            // Update the dictionary.
            If (!doRemoveComponent(component))
                Return;

            // Deal with pending.
            If(component.isRegistered == False)
            {
                // Remove it from the deferred list.
                For(var i:Int=0; i<_deferredComponents.length; i++)
                {
                    If((_deferredComponents[i] as PendingComponent).item != component)
                        Continue;

                    // TODO: Forcibly call register/unregister To ensure onAdd/onRemove semantics?

                    _deferredComponents.splice(i, 1);
                    break;
                }

                Return;
            }

            component.unregister();

            doResetComponents();
#End            
	End Method

	Method LookupComponentByType:IEntityComponent(componentType:String)
#rem        {
            For each(var component:IEntityComponent in _components)
            {
                If (component is componentType)
                    Return component;
            }
#End
            Return Null;
	End Method

	'Method LookupComponentsByType:Array(componentType:String)
	Method LookupComponentsByType:List<IEntityComponent>(componentType:String)
#rem
            var list:Array = New Array();

            For each(var component:IEntityComponent in _components)
            {
                If (component is componentType)
                    list.push(component);
            }

            Return list;
#End
		Return Null
	End Method

	Method LookupComponentByName:IEntityComponent(componentName:String)
#rem
        {
            Return _components[componentName];
#End
		Return Null
	End Method

	Method DoesPropertyExist:Bool(propRef:PropertyReference)
		'Return findProperty(Property, False, _tempPropertyInfo, True) != Null;
		Return True
	End Method

	Method GetProperty:Object(propRef:PropertyReference, defaultVal:Object = Null)
#rem
            // Look up the Property.
            var info:PropertyInfo = findProperty(Property, False, _tempPropertyInfo);
            var result:* = Null;

            // Get value If any.
            If (info)
                result = info.getValue();
            Else
                result = defaultVal;

            // Clean up To avoid dangling references.
            _tempPropertyInfo.clear();

            Return result;
#End
		Return Null
	End Method

	Method SetProperty:Void(propRef:PropertyReference, value:Object)
#rem
            // Look up And set.
            var info:PropertyInfo = findProperty(Property, True, _tempPropertyInfo);
            If (info)
                info.setValue(value);

            // Clean up To avoid dangling references.
            _tempPropertyInfo.clear();
#End            
	End Method


#rem
        Private Function doAddComponent(component:IEntityComponent, componentName:String):Boolean
        {
            If (componentName == "")
            {
                Logger.warn(this, "AddComponent", "A component name was not specified. This might cause problems later.");
            }

            If (component.owner)
            {
                Logger.Error(this, "AddComponent", "The component " + componentName + " already has an owner. (" + name + ")");
                Return False;
            }

            If (_components[componentName])
            {
                Logger.Error(this, "AddComponent", "A component with name " + componentName + " already exists on this entity (" + name + ").");
                Return False;
            }

            component.owner = this;
            _components[componentName] = component;
            Return True;
        }

        Private Function doRemoveComponent(component:IEntityComponent):Boolean
        {
            If (component.owner != this)
            {
                Logger.Error(this, "AddComponent", "The component " + component.name + " is not owned by this entity. (" + name + ")");
                Return False;
            }

            If (!_components[component.name])
            {
                Logger.Error(this, "AddComponent", "The component " + component.name + " was not found on this entity. (" + name + ")");
                Return False;
            }

            delete _components[component.name];
            Return True;
        }

        /**
         * Call reset on all the registered components in this entity.
         */
        Private Function doResetComponents():Void
        {
            var oldDefer:Boolean = _deferring;
            deferring = True;
            For each(var component:IEntityComponent in _components)
            {
                // Skip unregistered entities. 
                If(!component.isRegistered)
                    Continue;

                // Reset it!
                component.reset();
            }
            deferring = False;
        }

        Private Function findProperty(reference:PropertyReference, willSet:Boolean = False, providedPi:PropertyInfo = Null, suppressErrors:Boolean = False):PropertyInfo
        {
            // TODO: we use appendChild but relookup the results, can we just use Return value?

            // Early out If we got a Null Property reference.
            If (!reference || reference.Property == Null || reference.Property == "")
                Return Null;

            Profiler.enter("Entity.findProperty");

            // Must have a propertyInfo To operate with.
            If(!providedPi)
                providedPi = New PropertyInfo();

            // Cached lookups apply only To components.
            If(reference.cachedLookup && reference.cachedLookup.length > 0)
            {
                var cl:Array = reference.cachedLookup;
                var cachedWalk:* = lookupComponentByName(cl[0]);
                If(!cachedWalk)
                {
                    If(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not resolve component named '" + cl[0] + "' for property '" + reference.Property + "' with cached reference. " + Logger.getCallStack());
                    Profiler.Exit("Entity.findProperty");
                    Return Null;
                }

                For(var i:Int = 1; i<cl.length - 1; i++)
                {
                    cachedWalk = cachedWalk[cl[i]];

                    If(cachedWalk == Null)
                    {
                        If(!suppressErrors)
                            Logger.warn(this, "findProperty", "[#"+this.name+"] Could not resolve property '" + cl[i] + "' for property reference '" + reference.Property + "' with cached reference"  + Logger.getCallStack());
                        Profiler.Exit("Entity.findProperty");
                        Return Null;
                    }
                }

                var cachedPi:PropertyInfo = providedPi;
                cachedPi.propertyParent = cachedWalk;
                cachedPi.propertyName = (cl.length > 1) ? cl[cl.length-1] : Null;
                Profiler.exit("Entity.findProperty");
                return cachedPi;
            }

            // Split up the property reference.      
            var propertyName:String = reference.Property;
            var path:Array = propertyName.split(".");

            // Distinguish if it is a component reference (@), named object ref (#), or
            // an XML reference (!), and look up the first element in the path.
            var isTemplateXML:Boolean = False;
            var itemName:String = path[0];
            var curIdx:int = 1;
            var startChar:String = itemName.charAt(0);
            var curLookup:String = itemName.slice(1);
            var parentElem:*;
            if(startChar == "@")
            {
                // Component reference, look up the component by name.
                parentElem = lookupComponentByName(curLookup);
                if(!parentElem)
                {
                    If(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not resolve component named '" + curLookup + "' for property '" + reference.property + "'");
                    Profiler.exit("Entity.findProperty");
                    return null;
                }

                // Cache the split out String.
                path[0] = curLookup;
                reference.cachedLookup = path;
            }
            else if(startChar == "#")
            {
                // Named object reference. Look up the entity in the NameManager.
                parentElem = PBE.nameManager.lookup(curLookup);
                if(!parentElem)
                {
                    if(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not resolve named object named '" + curLookup + "' for property '" + reference.property + "'");
                    Profiler.exit("Entity.findProperty");
                    Return Null;
                }

                // Get the component on it.
                curIdx++;
                curLookup = path[1];
                var comLookup:IEntityComponent = (parentElem as IEntity).lookupComponentByName(curLookup);
                if(!comLookup)
                {
                    if(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not find component '" + curLookup + "' on named entity '" + (parentElem as IEntity).name + "' for property '" + reference.Property + "'");
                    Profiler.exit("Entity.findProperty");
                    return null;
                }
                parentElem = comLookup;
            }
            else if(startChar == "!")
            {
                // XML reference. Look it up inside the TemplateManager. We only support
                // templates and entities - no groups.
                parentElem = PBE.templateManager.getXML(curLookup, "template", "entity");
                if(!parentElem)
                {
                    If(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not find XML named '" + curLookup + "' for property '" + reference.Property + "'");
                    Profiler.exit("Entity.findProperty");
                    return null;
                }

                // Try To find the specified component.
                curIdx++;
                var nextElem:* = null;
                for each(var cTag:* in parentElem.*)
                {
                    if(cTag.@name == path[1])
                    {
                        nextElem = cTag;
                        break;
                    }
                }

                // Create it if appropriate.
                If(!nextElem && willSet)
                {
                    // Create component tag.
                    (parentElem as XML).appendChild(<component name={path[1]}/>);

                    // Look it up again.
                    for each(cTag in parentElem.*)
                    {
                        if(cTag.@name == path[1])
                        {
                            nextElem = cTag;
                            break;
                        }
                    }
                }

                // Error if we don't have it!
                if(!nextElem)
                {
                    If(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not find component '" + path[1] + "' in XML template '" + path[0].slice(1) + "' for property '" + reference.property + "'");
                    Profiler.exit("Entity.findProperty");
                    return null;
                }

                // Get ready to search the rest.
                parentElem = nextElem;

                // Indicate we are dealing with xml.
                isTemplateXML = true;
            }
            Else
            {
                if(!suppressErrors)
                    Logger.warn(this, "findProperty", "[#"+this.name+"] Got a property path that doesn't start with !, #, or @. Started with '" + startChar + "' for property '" + reference.property + "'");
                Profiler.exit("Entity.findProperty");
                return null;
            }

            // Make sure we have a field to look up.
            if(curIdx < path.length)
                curLookup = path[curIdx++] as String;
            Else
                curLookup = null;

            // Do the remainder of the look up.
            while(curIdx < path.length && parentElem)
            {
                // Try the next element in the path.
                var oldParentElem:* = parentElem;
                Try
                {
                    if(parentElem is XML || parentElem is XMLList)
                        parentElem = parentElem.child(curLookup);
                    else
                        parentElem = parentElem[curLookup];
                }
                catch(e:Error)
                {
                    parentElem = Null;
                }

                // Several different possibilities that indicate we failed to advance.
                var gotEmpty:Boolean = false;
                if(parentElem == undefined) gotEmpty = true;
                If(parentElem == Null) gotEmpty = True;
                if(parentElem is XMLList && parentElem.length() == 0) gotEmpty = true;

                // If we're going to set and it's XML, create the field.
                if(willSet && isTemplateXML && gotEmpty && oldParentElem)
                {
                    oldParentElem.appendChild(<{curLookup}/>);
                    parentElem = oldParentElem.child(curLookup);
                    gotEmpty = False;
                }

                if(gotEmpty)
                {
                    if(!suppressErrors)
                        Logger.warn(this, "findProperty", "[#"+this.name+"] Could not resolve property '" + curLookup + "' for property reference '" + reference.property + "'");
                    Profiler.exit("Entity.findProperty");
                    return null;
                }

                // Advance To Next element in the path.
                curLookup = path[curIdx++] as String;
            }

            // Did we End up with a match?
            if(parentElem)
            {
                var pi:PropertyInfo = providedPi;
                pi.propertyParent = parentElem;
                pi.propertyName = curLookup;
                Profiler.exit("Entity.findProperty");
                return pi;
            }

            Profiler.exit("Entity.findProperty");
            return null;
        }
#End
	Field _deferring:Bool = True
#rem
        protected var _components:Dictionary = New Dictionary();
        protected var _tempPropertyInfo:PropertyInfo = new PropertyInfo();
        protected var _deferredComponents:Array = New Array();
        protected var _eventDispatcher:EventDispatcher = new EventDispatcher();
#End
End Class

' Utility Class To manage a group of entities marked with GroupManagerComponent.
Class GroupManagerComponent Extends EntityComponent

	Field _members:List<GroupMemberComponent> = New List<GroupMemberComponent>()
	Field autoCreateNamedGroups:Bool = True

	Method GetGroupByName:GroupManagerComponent(name:String)

		Local groupName:String = name;
		Print "TODO - gm is always null for now!"
		Local gm:GroupManagerComponent
		'Local gm:GroupManagerComponent = PBE.lookupComponentByType(groupName, GroupManagerComponent) as GroupManagerComponent
         
		'If gm = Null
			If Not autoCreateNamedGroups
				Print "GetGroupByName - Tried to reference non-existent group '" + groupName + "'"
			Else 
				Local ent:IEntity = New Entity()
				ent.Initialize(groupName);
              
				gm = New GroupManagerComponent();
             
				ent.AddComponent(gm, name);
			End If
		'End If

		Return gm
	
	End Method

	Method AddMember:Void(member:GroupMemberComponent)

		_members.AddLast(member);

	End Method
      
	Method RemoveMember:Void(member:GroupMemberComponent)
		'var idx:Int = _members.indexOf(member);
		'If(idx == -1)
		'	Throw New Error("Removing a member which does not exist in this group.");
		'_members.splice(idx, 1);

		_members.RemoveEach(member)

	End Method
      
	Method EntityList:List<IEntity>()

		Local a:List<IEntity> = New List<IEntity>();
         
		For Local m:GroupMemberComponent = Eachin _members
			a.AddLast(m.Owner());
		End For
            
		Return a;

	End Method

End Class

' Helper component To group entities.
Class GroupMemberComponent Extends EntityComponent

	Field _groupName:String = ""
	Field _currentManager:GroupManagerComponent = Null
      
	Method GroupManager:GroupManagerComponent()
		Local gmc:GroupManagerComponent = New GroupManagerComponent()
		Return gmc.GetGroupByName(_groupName);
	End Method

	Method GroupName:Void(value:String)
		OnRemove();
		_groupName = value;
		OnAdd();
	End Method
      
	Method GroupName:String()
		Return _groupName;
	End Method
      
	Method OnAdd:Void()
		Local curM:GroupManagerComponent = GroupManager();
		If Not _currentManager And curM
			_currentManager = curM;
			_currentManager.AddMember(Self);
		End If
	End Method
      
	Method OnReset:Void()
		OnRemove();
		OnAdd();
	End Method
      
	Method OnRemove:Void()
		If _currentManager
			_currentManager.RemoveMember(Self);
			_currentManager = Null;            
		End If
	End Method

End Class

Class NetGame Extends App

	Field onTickInterval:Int = 0

	' Stuff to do on startup...
	Method OnCreate ()
		' 60 frames per second, please!
		SetUpdateRate 60
		
		onTickInterval = Millisecs()
	End Method

	' Stuff to do while running...
	Method OnUpdate ()

		If Millisecs - onTickInterval > 100 Then
			Local ni:NetworkInterface = New NetworkInterface()
			ni.Tick()
			ni.interval = 100
		End If

	End Method

	' Drawing code...
	Method OnRender ()
		Cls 0, 0, 0						' Clear screen
	End Method

End Class

Function Main ()
	
	Print "Hello World"


	
	Local gt:GhostTests = New GhostTests()
	gt.TestHalfDuplexGhosting()
	
	For Local i:Int = 0 Until 8
	
		Print ""
	
	End For
	
	New NetGame

End Function

#rem
#End

'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------






Class PBNetworkingServer

	Const DEFAULT_PORT:Int = 1337;

	Field started:Boolean = False;
	Field swfPath:String = Null;
	Field serverGameClass:String = Null;
	Field port:Int = DEFAULT_PORT;

	Field configLoader:URLLoader;
	Field swfLoader:Loader;

	Field serverSocket:ServerSocket;
	Field serverGame:IServerGame;   

	Method onInvoke:Void(e:InvokeEvent)

		Print "Invoked: " + e.arguments

		' If we are allready started just Return
		If started 
			Return
		End If

		' Set started so this only happens once
		started = True;
                
		' Activate the window so enter frames are send
		stage.nativeWindow.Activate();     

		' Load config
		LoadConfig();

	End Method
            
	Method loadConfig:Void()

		configLoader = New URLLoader();
		configLoader.addEventListener(Event.COMPLETE, onConfigLoaded);
		configLoader.addEventListener(IOErrorEvent.IO_ERROR, onConfigError);
		configLoader.load(New URLRequest("app:/config.xml"));

	End Method
            
	Method onConfigLoaded:Void(e:Event)

		e.target.removeEventListener(Event.COMPLETE, onConfigLoaded);
		e.target.removeEventListener(IOErrorEvent.IO_ERROR, onConfigError);

		ParseConfig();

	End Method
            
	Method onConfigError:Void(e:IOErrorEvent)

		e.target.removeEventListener(Event.COMPLETE, onConfigLoaded);
		e.target.removeEventListener(IOErrorEvent.IO_ERROR, onConfigError);                

		Error "Could not loading config from config.xml"

	End Method
            
	Method ParseConfig:Void()

		Local config:XML = New XML(configLoader.data);
		Print config.toXMLString()
                
 		' Parse the config
		For Local child:XML = Eachin config.children()

			If child.name() = "port"
				this.port = child.valueOf();
			End If

			If child.name() = "serverGameClass"
				this.serverGameClass = child.valueOf(); 
			End If

			If child.name() = "swf"
				this.swfPath = child.valueOf(); 
			End If

		End For

		If Not swfPath
			Error "swf is not specified in config"
		End If

		If Not serverGameClass
			Error "serverGameClass is not specified in config"
		End If

		Print "Connecting to: " + swfPath + serverGameClass + port

		this.loadSWF()

	End Method

	Method loadSWF:Void()

		' NOTE: AIR cannot load swf files outside the app:// directory. The workaround
		' is To load the bytes first And than load the swf from the bytes

		this.swfLoader = New Loader();
		this.swfLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onSWFLoaded);
		this.swfLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onSWFError);
		this.swfLoader.load(New URLRequest("app:/"+this.swfPath), New LoaderContext(False, ApplicationDomain.currentDomain));   

	End Method

	Method onSWFError:Void(e:IOErrorEvent)

		e.target.removeEventListener(Event.COMPLETE, onSWFLoaded);
		e.target.removeEventListener(IOErrorEvent.IO_ERROR, onSWFError);

		Error "Could not load the swf from '"+this.swfPath+"' error: "+e.text

	End Method

	Method onSWFLoaded:Void(e:Event)

		e.target.removeEventListener(Event.COMPLETE, onSWFLoaded);
		e.target.removeEventListener(IOErrorEvent.IO_ERROR, onSWFError);

		Print "SWF loaded from '"+this.swfPath+"'"

		InitializeServerGame();

	End Method

	Method InitializeServerGame:Void()

		Print "Initializing IServerGame"

		Try

			Local serverGameType:Class = getDefinitionByName(serverGameClass) as Class;

			Print "Class: " + serverGameType

			serverGame = New serverGameType();
			Logger.RegisterListener(this);
			serverGame.onStart(this);

			' Initialize the socket
			InitializeSocket();

		Catch e:NetError

			Error "Could not instantiate IServerGame type '"+serverGameClass+"' error: "+e.message
			Throw e

		End Try

	End Method

	Method InitializeSocket:Void()

		' Setup the server socket
		serverSocket = New ServerSocket();
		serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
		serverSocket.bind(port);
		serverSocket.listen();      

		' Start the debug visualize
		NetworkDebugVisualizer.smEnabled = True;     

		' Note: now we are finished in the server 

	End Method

	Method Error:Void(message:String)

		Print "Error: " + message
		Alert.show(message, "Fatal Error");

	End Method
            
	Method onConnect:Void(e:ServerSocketConnectEvent)
		serverGame.onConnection(e.socket);
	End Method
            
	' Last six chat/log messages are stored here.
	Field lastLogMessages:Array = New Array(100);
            
	' Add log messages To the chat window
	Method addLogMessage(level:String, loggerName:String, message:String):Void{

		lastLogMessages.push(level+": " + loggerName+" - "+ message);
		lastLogMessages.shift();
                
		UpdateLogWindow();           

	End Method
            
	' Fill the chat window with the last few chat messages.
	Method UpdateLogWindow():Void

		logTextArea.text = "";
		For each(var m:String in lastLogMessages)
			logTextArea.text += (m != Null ? m : "") + "\n";
		End For
                
		logTextArea.verticalScrollPosition = logTextArea.maxVerticalScrollPosition;

	End Method

End Class

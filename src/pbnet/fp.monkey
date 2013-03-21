
Strict

Import pbnet

Interface FunctionPointer

	Method Main:Void()
	
End Interface

Class IEntity

	Field netRoot:NetRoot
	Field ghostComponent:GhostComponent
	Field name:String = ""

	Method New(nr:NetRoot)
	
		netRoot = nr
		ghostComponent = New GhostComponent(netRoot)
		name = ""
	
	End Method
	
	Method GetProperty:Object(pr:String)
	
		Return Null
	
	End Method
	
	Method SetProperty:Void(pr:String, nv:Object)
	
	End Method
	
	Method Destroy:Void()
	
	End Method

End Class

#rem
' Minimal Interface For accessing properties on some Object.
Interface IPropertyBag

	' The event dispatcher that controls events For this entity. Components should
	' use this To dispatch And listen For events.
	'Method EventDispatcher:IEventDispatcher()

	' Checks whether a Property exists on this entity.
	' 
	' @param Property The Property reference describing the Property To look For on
	' this entity.
	' 
	' @Return True If the Property exists, False otherwise.
	Method DoesPropertyExist:Bool(propRef:PropertyReference)
      
	' Gets the value of a Property on this entity.
	' 
	' @param Property The Property reference describing the Property To look For on
	' this entity.
	' @param defaultValue If the Property is Not found, Return this value.
	' 
	' @Return The current value of the Property, Or Null If it doesn't exist.
	Method GetProperty:Object(propRef:PropertyReference, defaultValue:Object = Null)
      
	' Sets the value of a Property on this entity.
	' 
	' @param Property The Property reference describing the Property To look For on
	' this entity.
	' 
	' @param value The value To set on the specified Property.
	Method SetProperty:Void(propRef:PropertyReference, value:Object)

End Interface
#End

#rem
' A Property reference stores the information necessary To lookup a Property
' on an entity.
'
' <p>These are used To facilitate retrieving information from entities without
' requiring a specific Interface To be implemented. For example, a component that
' handles display information would need To retrieve spatial information from a
' spatial component. The spatial component can store its information however it
' sees fit. The display component would have a PropertyReference member that would
' be initialized To the path of the desired Property on the spatial component.</p>
'
' <p>Property References follow one of three formats, component lookup, Global
' entity lookup, Or xml lookup.  For component lookup the Property reference
' should start with an &#64;, For Global entity lookup the Property reference should
' start with a #, And For xml lookup the Property reference should start with a !.
' Following this starting symbol comes the name of the component, entity Or XML
' Template respectively.</p>
'
' @example The following code gets the x Property of the position Property of the
' spatial component on the queried Entity: <listing version="3.0">
' &#64;spatial.position.x
' </listing>
'
' @example Property references can also access arrays And dictionaries.  The following
' Property reference is equivalent To ai.targets[0].x: <listing version="3.0">
' &#64;ai.targets.0.x
' </listing>
'
' @example Global entities can be accessed with the # symbol.  The following code accesses
' the Level entity's timer component and retrieves the timeLeft property: <listing version="3.0">
' #Level.timer.timeLeft
' </listing>
'
' @example XML Template properties can be accessed using the ! symbol.  The following code accesses
' the XML Template name Enemy And retrieves the health Property off of the life component: <listing version="3.0">
' !Enemy.life.health
' </listing>
'
' @see IPropertyBag#doesPropertyExist()
' @see IPropertyBag#getProperty()
' @see IPropertyBag#setProperty()
'/
Class PropertyReference Implements ISerializable

	' The path To the Property that this references.
	Method Prop:String()
	
		Return _property
	
	End Method

	' @Private
	Method Prop:Void(value:String)
	
		If _property <> value
			'cachedLookup = Null
		End If
		
		_property = value;
		
	End Method

	Method New(prop:String = "")
		_property = prop;
	End Method

	' @inheritDoc
	Method Serialize:Void(xml:String)

		'xml.appendChild(New XML(_property));
		xml += _property

	End Method

	' @inheritDoc
	Method Deserialize:Object(xml:String)

		If _property And _property <> xml
			Print "deserialize - Overwriting property; was '" + _property + "', new value is '" + xml + "'"
		End If

		_property = xml;

		Return Self

	End Method

	Method ToString:String()
		Return _property;
	End Method

	Field _property:String = ""
	'Field cachedLookup:Array

End Class
#End

#rem
' Interface For a named Object that can exist in a group Or set.
'
' @see PBSet, PBGroup, IEntity
Interface IPBObject

	' The name of the PBObject. This is set by passing a name To the initialize
	' Method after the PBObject is first created.
	'
	' @see #initialize()
	Method Name:String()

	' Since the PBE level format references template definitions by name, And
	' that same name is used To name the entities created by the format, it
	' is useful To be able To look things up by a common name. So you might
	' have Level1Background, Level2Background, Level3Background etc. but give
	' them all the alias LevelBackground so you can look up the current level's
	' background easily.
	'
	' <p>This is set by the second parameter To #initialize()</p>
	Method ObjAlias:String()

	' The PBGroup which owns this PBObject. If the owning group is destroy()ed,
	' the PBObject is destroy()ed as well. This is useful For managing Object
	' lifespans - for instance, all the PBObjects in a level might belong
	' to one common group for easy cleanup.
	Method OwningGroup:Void(value:PBGroup)
	Method OwningGroup:PBGroup()

	' initializes the PBObject, optionally assigning it a name. This should be
	' called immediately after the PBObject is created.
	'
	' @param name The name To assign To the PBObject. If this is Null Or an empty
	' String, the PBObject will Not register itself with the name manager.
	'
	' @param alias An alternate name under which this PBObject can be looked up.
	' Useful when you need to distinguish between multiple things but refer
	' to the active one by a consistent name.
	'
	' @see com.pblabs.engine.core.NameManager
	Method Initialize:Void(name:String = "", objAlias:String = "")

	' Destroys the PBObject by removing all components And unregistering it from
	' the name manager.
	'
	' <p>PBObjects are automatically removed from any groups/sets that they
	' are members of when they are destroy()'ed.</p>
	'
	' <p>Currently this will not invalidate any other references to the PBObject
	' so the PBObject will only be cleaned up by the garbage collector if those
	' are set to null manually.</p>
	Method Destroy:Void()

End Interface
#End

#rem    
' Game objects in PBE are referred To as entities. This Interface defines the
' behavior For an entity. A full featured implementation of this Interface is
' included, but is hidden so as To force using IEntity when storing references
' To entities. To create a New entity, use allocateEntity.
' 
' <p>An entity by itself is a very light weight Object. All it needs To store is
' its name And a list of components. Custom functionality is added by creating
' components And attaching them To entities.</p>
' 
' <p>An event with type "EntityDestroyed" will be fired when the entity is
' destroyed via the Destroy() Method. This event is fired before any cleanup
' is done.</p>
'  
' @see IEntityComponent
' @see com.pblabs.engine.entity.allocateEntity()
Interface IEntity Extends IPropertyBag, IPBObject

	' When True, onAdd/onRemove callbacks are deferred. When set To False, any
	' pending callbacks are processed.
	Method Deferring:Void(value:Bool)
	Method Deferring:Bool()

	' Adds a component To the entity.
	' 
	' <p>When a component is added, it will have its register() Method called
	' (Or onAdd If it is derived from EntityComponent). Also, reset() will be
	' called on all components currently attached To the entity (Or onReset
	' If it is derived from EntityComponent).</p>
	' 
	' @param component The component To add.
	' @param componentName The name To set For the component. This is the value
	'        To use in lookupComponentByName To get a reference To the component.
	'        The name must be unique across all components on this entity.
	Method AddComponent:Bool(component:IEntityComponent, componentName:String)

	' Removes a component from the entity.
	' 
	' <p>When a component is removed, it will have its Unregister Method called
	' (Or onRemove If it is derived from EntityComponent). Also, Reset will be
	' called on all components currently attached To the entity (Or onReset
	' If it is derived from EntityComponent).</p>
	' 
	' @param component The component To remove.
	Method RemoveComponent:Void(component:IEntityComponent)
      
	' Creates an XML description of this entity, including all currently attached
	' components.
	' 
	' <p>This is Not implemented yet.</p>
	' 
	' @param xml The xml Object describing the entity. The parent tag should be
	' included in this variable when the Function is called, so only child tags
	' need To be created.
	Method Serialize:Void(xml:String)

	' Sets up this entity from an xml description.
	' 
	' @param xml The xml Object describing the entity.
	' @param registerComponents Set this To False To add components To the entity
	' without registering them. This is used by the level manager To facilitate
	' creating entities from templates. 
	Method Deserialize:Void(xml:String, registerComponents:Bool = True)

	' <p>Gets a component of a specific type from this entity. If more than one
	' component of a specific type exists, there is no guarantee which one
	' will be returned. To retrieve all components of a specified type, use
	' lookupComponentsByType.</p>
	' 
	' <p>This check uses the is operator, so If you pass a parent type,
	' subclasses will be considered To match, as will things implementing
	' an Interface you have passed.</p>
	'
	' @param componentType The type of the component To retrieve.
	'
	' @Return The component, Or Null If none of the specified type were found.
	' 
	' @see #lookupComponentsByType()
	'Method LookupComponentByType:IEntityComponent(componentType:Class)
	Method LookupComponentByType:IEntityComponent(componentType:String)

	' Gets a list of all the components of a specific type that are on this
	' entity.
	'
	' <p>This check uses the is operator, so If you pass a parent type,
	' subclasses will be considered To match, as will things implementing
	' an Interface you have passed.</p>
	'
	' @param componentType The type of components To retrieve.
	' 
	' @Return An Array containing all the components of the specified type on
	' this entity.
	'Method LookupComponentsByType:Array(componentType:Class)
	Method LookupComponentsByType:List<IEntityComponent>(componentType:String)
      
	' Gets a component that was registered with a specific name on this entity.
	'
	' @param componentName The name of the component To retrieve. This corresponds
	' To the second parameter passed To AddComponent.
	' 
	' @Return The component with the specified name.
	' 
	' @see #AddComponent()
	Method LookupComponentByName:IEntityComponent(componentName:String)

End Interface
#End

' Helper class to store information about each thing.
Class ThingReference

	Field version:Int = 0
	Field xmlData:XMLElement = Null
	Field entityCallback:FunctionPointer = Null
	Field groupCallback:FunctionPointer = Null
	Field identifier:String = ""

End Class

' A component in PBE is used To define specific pieces of functionality For
' game entities. Several components can be added To a single entity To give
' the entity complex behavior While keeping the different functionalities separate
' from each other.
' 
' <p>A full featured implementation of this Interface is included (EntityComponent).
' It should be adequate For almost every situation, And therefore, custom components
' should derive from it rather than implementing this Interface directly.</p>
' 
' <p>There are several reasons why PBE is set up this way:
' <bl>
'    <li>Entities have only the data they need And nothing more.</li>
'    <li>Components can be reused on several different types of entities.</li>
'    <li>Programmers can focus on specific pieces of functionality when writing code.</li>
' </bl>
' </p>
' 
' @see IEntity
' @see EntityComponent
' @see http://pushbuttonengine.com/docs/04-Components.html Components chapter in manual.
Interface IEntityComponent

	' A reference to the entity that this component currently belongs to. If
	' the component has not been added to an entity, this will be null.
	'
	' <p>This value should be equivalent To the first parameter passed To the register
	' Method.</p>
	' 
	' @see #register() 
	Method Owner:IEntity()

	' Set the owner. This should only be set by the owning IEntity.
	Method Owner:Void(value:IEntity)

	' The name given To the component when it is added To an entity.
	' 
	' This value should be equivelent To the second parameter passed To the register
	' Method.
	' 
	' @see #register() 
	Method Name:String()
      
	' Whether Or Not the component is currently registered with an entity.
	Method IsRegistered:Bool()

	' Registers the component with an entity. This should only ever be called by
	' an IEntity from the addComponent Method.
	'
	' @param owner The entity To register the component with.
	' @param name The name To assign To the component.
	Method Register:Void(owner:IEntity, name:String)
      
	' Unregisters the component from an entity. This should only ever be called by
	' an entity Class from the removeComponent Method.
	Method Unregister:Void()
      
	' This is called by an entity on all of its components any time a component
	' is added Or removed. In this Method, any references To properties on the
	' owner entity should be purged And re-looked up.
	Method Reset:Void()

End Interface

' An implementation of the IEntityComponent interface, providing all the basic
' functionality required of all components. Custom components should always
' derive from this Class rather than implementing IEntityComponent directly.
' 
' @see IEntity
Class EntityComponent Implements IEntityComponent

	' @inheritDoc
	Method Owner:IEntity()
		Return _owner;
	End Method

	Method Owner:Void(value:IEntity)
		_owner = value;
	End Method

	' @inheritDoc
	Method Name:String()
         Return _name;
	End Method

	' @inheritDoc
	Method IsRegistered:Bool()
		Return _isRegistered;
	End Method

	' @inheritDoc
	Method Register:Void(owner:IEntity, name:String)

		If IsRegistered()
			Throw New NetError("Trying to register an already-registered component!");
		End If
            
		_name = name;
		_owner = owner;
		OnAdd();
		_isRegistered = True;

	End Method
      
	' @inheritDoc
	Method Unregister:Void()

		If Not IsRegistered()
			Throw New NetError("Trying to unregister an unregistered component!");
		End If

		_isRegistered = False
		OnRemove()
		_owner = Null
		_name = ""

	End Method
      
	' @inheritDoc
	Method Reset:Void()
		OnReset();
	End Method
      
	' This is called when the component is added To an entity. Any initialization,
	' event registration, Or Object lookups should happen here. Component lookups
	' on the owner entity should Not happen here. Use onReset instead.
	'
	' @see #onReset()
	Method OnAdd:Void()

	End Method
      
	' This is called when the component is removed from an entity. It should reverse
	' anything that happened in onAdd Or onReset (like removing event listeners Or
	' nulling Object references).
	Method OnRemove:Void()

	End Method
      
	' This is called anytime a component is added Or removed from the owner entity.
	' Lookups of other components on the owner entity should happen here.
	' 
	' <p>This can potentially be called multiple times, so make sure previous lookups
	' are properly cleaned up each time.</p>
	Method OnReset:Void()

	End Method
      
	Field _isRegistered:Bool = False
	Field _owner:IEntity = Null
	Field _name:String = ""

End Class

' This Interface should be implemented by objects that need To perform
' actions every tick, such as moving, Or processing collision. Performing
' events every tick instead of every frame will give more consistent And
' correct results. However, things related To rendering Or animation should
' happen every frame so the visual result appears smooth.
' 
' <p>Along with implementing this Interface, the Object needs To be added
' To the ProcessManager via the AddTickedObject Method.</p>
' 
' @see ProcessManager
' @see IAnimatedObject
Interface ITickedObject

	' This Method is called every tick by the ProcessManager on any objects
	' that have been added To it with the AddTickedObject Method.
	' 
	' @param deltaTime The amount of time (in seconds) specified For a tick.
	' 
	' @see ProcessManager#AddTickedObject()
	Method OnTick:Void(deltaTime:Float)

End Interface

Class OnOutOfScope Implements FunctionPointer

	Field owner:IEntity

	Method New(o:IEntity)
	
		owner = o
	
	End Method
	
	Method Main:Void()
	
		owner.Destroy()
	
	End Method

End Class



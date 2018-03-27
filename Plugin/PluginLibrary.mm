//
//  PluginLibrary.mm
//  TemplateApp
//
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PluginLibrary.h"

#include <CoronaRuntime.h>
#import <UIKit/UIKit.h>
#import <NeuraSDK/NeuraSDK.h>
#import <CoronaLuaIOS.h>

// ----------------------------------------------------------------------------

class PluginLibrary
{
	public:
		typedef PluginLibrary Self;

	public:
		static const char kName[];
		static const char kEvent[];

	protected:
		PluginLibrary();

	public:
		bool Initialize( CoronaLuaRef listener );

	public:
		CoronaLuaRef GetListener() const { return fListener; }

	public:
		static int Open( lua_State *L );

	protected:
		static int Finalizer( lua_State *L );

	public:
		static Self *ToLibrary( lua_State *L );

	public:
		static int init( lua_State *L );
		static int show( lua_State *L );
        static int authenticate( lua_State *L );
        static int simulateAnEvent( lua_State *L);
        static int subscribeToEvent( lua_State *L);
        static int isLoggedIn( lua_State *L );
        static int logout( lua_State *L );

	private:
		CoronaLuaRef fListener;
};

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.neura"
const char PluginLibrary::kName[] = "plugin.neura";

// This corresponds to the event name, e.g. [Lua] event.name
const char PluginLibrary::kEvent[] = "pluginlibraryevent";

PluginLibrary::PluginLibrary()
:	fListener( NULL )
{
}

bool
PluginLibrary::Initialize( CoronaLuaRef listener )
{
	// Can only initialize listener once
	bool result = ( NULL == fListener );

	if ( result )
	{
		fListener = listener;
	}

	return result;
}

int
PluginLibrary::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
    
	// Functions in library
	const luaL_Reg kVTable[] =
	{
		{ "init", init },
		{ "show", show },
        { "authenticate", authenticate },
        { "simulateAnEvent", simulateAnEvent },
        { "subscribeToEvent", subscribeToEvent },
        { "isLoggedIn", isLoggedIn },
        { "logout", logout },
        
		{ NULL, NULL }
	};

	// Set library as upvalue for each library function
	Self *library = new Self;
	CoronaLuaPushUserdata( L, library, kMetatableName );

	luaL_openlib( L, kName, kVTable, 1 ); // leave "library" on top of stack
    
	return 1;
}

int
PluginLibrary::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );

	CoronaLuaDeleteRef( L, library->GetListener() );

	delete library;

	return 0;
}

PluginLibrary *
PluginLibrary::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

// [Lua] library.init( listener )
int
PluginLibrary::init( lua_State *L )
{
	int listenerIndex = 1;

	if ( CoronaLuaIsListener( L, listenerIndex, kEvent ) )
	{
		Self *library = ToLibrary( L );

		CoronaLuaRef listener = CoronaLuaNewRef( L, listenerIndex );
		library->Initialize( listener );
        
        //TODO - Parse app id and app secret from dictionary
        NSDictionary* dict = CoronaLuaCreateDictionary(L, 1);
        NSString * message = [NSString stringWithFormat:@"App data = %@", dict];
        
        // Create event and add message to it
        CoronaLuaNewEvent( L, kEvent );
        lua_pushstring( L, [message UTF8String] );
        lua_setfield( L, -2, "message" );
        
        // Dispatch event to library's listener
        CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
	}


	return 0;
}

// [Lua] library.show( word )
int
PluginLibrary::show( lua_State *L )
{
	NSString *message = @"Error: Could not display UIReferenceLibraryViewController. This feature requires iOS 5 or later.";
	
	if ( [UIReferenceLibraryViewController class] )
	{
		id<CoronaRuntime> runtime = (id<CoronaRuntime>)CoronaLuaGetContext( L );

		const char kDefaultWord[] = "corona";
		const char *word = lua_tostring( L, 1 );
		if ( ! word )
		{
			word = kDefaultWord;
		}

		UIReferenceLibraryViewController *controller = [[[UIReferenceLibraryViewController alloc] initWithTerm:[NSString stringWithUTF8String:word]] autorelease];

		// Present the controller modally.
		[runtime.appViewController presentViewController:controller animated:YES completion:nil];

		message = @"Success. Displaying UIReferenceLibraryViewController for 'corona'.";
	}

	Self *library = ToLibrary( L );

    // Create event and add message to it
    CoronaLuaNewEvent( L, kEvent );
    lua_pushstring( L, [message UTF8String] );
    lua_setfield( L, -2, "message" );

    // Dispatch event to library's listener
    CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
    
   // authenticate(L);
    //logout(L);
    
	return 0;
}

int
PluginLibrary::authenticate( lua_State *L )
{
    Self *library = ToLibrary( L );
    
    NeuraAnonymousAuthenticationRequest *request = [NeuraAnonymousAuthenticationRequest new];
    [NeuraSDK.shared authenticateWithRequest:request callback:^(NeuraAuthenticationResult * _Nonnull result) {
         NSString *message = @"Login success";
        if (result.error) {
            
            // Handle authentication errors.
            message = @"Login error = ";
            message = [message stringByAppendingString:result.error.description];
        }
        
        // Create event and add message to it
        CoronaLuaNewEvent( L, kEvent );
        lua_pushstring( L, [message UTF8String] );
        lua_setfield( L, -2, "message" );
        
        // Dispatch event to library's listener
        CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
        
//        simulateAnEvent(L);
//        subscribeToEvent(L);
    }];

    
    return 0;
}

int
PluginLibrary::simulateAnEvent( lua_State *L) {
    char const *eventName = lua_tostring(L, 1);
    if (eventName == nil) return -1;
    
    NEventName enumEventName = [NEvent enumForEventName: [NSString stringWithUTF8String:eventName]];
    [NeuraSDK.shared simulateEvent:(enumEventName) callback:^(NeuraAPIResult * result){
        NSString * title = result.success ? @"Approve" : @"Error";
        NSString *message = @"Simulate an event: ";
   
        message = [message stringByAppendingString: title];
        
        Self *library = ToLibrary( L );
        
        CoronaLuaNewEvent( L, kEvent );
        lua_pushstring( L, [message UTF8String] );
        lua_setfield( L, -2, "message" );
        
        // Dispatch event to library's listener
        CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
    }];

    return 0;
}

int
PluginLibrary::subscribeToEvent(lua_State *L) {
    char const *eventNameChar = lua_tostring(L, 1);
    char const *eventIdChar = lua_tostring(L, 2);
    
    if (eventNameChar == nil || eventIdChar == nil) return -1;
    
    NSString * eventName = [NSString stringWithUTF8String: eventNameChar];
    NSString * eventId = [NSString stringWithUTF8String: eventIdChar];
    
    NSString *webhookId = nil;
    NSubscription *sub = [[NSubscription alloc] initWithEventName:eventName identifier:eventId webhookId:webhookId method:NSubscriptionMethodPush];
    
    [NeuraSDK.shared addSubscription:sub callback:^(NeuraAddSubscriptionResult * response){
        NSString *message =  [NSString stringWithFormat:@"%@%@", @"Failed subscription to", eventName];
        if (!response.error) { message = [NSString stringWithFormat:@"%@%@", @"Subscribed to:", eventName]; }
        
        Self *library = ToLibrary( L );
        
        CoronaLuaNewEvent( L, kEvent );
        lua_pushstring( L, [message UTF8String] );
        lua_setfield( L, -2, "message" );
        
        // Dispatch event to library's listener
        CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
        
    }];
    
    return 0;
}

int
PluginLibrary::isLoggedIn(lua_State *L) {
    lua_pushboolean(L, NeuraSDK.shared.isAuthenticated);
    return 1;
}

int
PluginLibrary::logout(lua_State *L) {
    if (!NeuraSDK.shared.isAuthenticated) return -1;
    
    [NeuraSDK.shared logoutWithCallback:^(NeuraLogoutResult * _Nonnull result) {
        NSString *message =  @"Logout status = ";
        NSString * title = result.success ? @"Approve" : @"Error";
        if (result.error != nil) { message = [message stringByAppendingString: title]; }
        
        Self *library = ToLibrary( L );
        
        CoronaLuaNewEvent( L, kEvent );
        lua_pushstring( L, [message UTF8String] );
        lua_setfield( L, -2, "message" );
        
        // Dispatch event to library's listener
        CoronaLuaDispatchEvent( L, library->GetListener(), 0 );
    }];
    
    return 0;
}

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_neura( lua_State *L )
{
	return PluginLibrary::Open( L );
}

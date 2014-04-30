/**
* 黄腾
* 梧州学院
* 2013年12月20日
*/
import com.smartfoxserver.v2.SmartFox;
import com.smartfoxserver.v2.core.SFSEvent;
import com.smartfoxserver.v2.entities.Room;
import com.smartfoxserver.v2.entities.User;
import com.smartfoxserver.v2.entities.data.ISFSObject;
import com.smartfoxserver.v2.entities.data.SFSObject;
import com.smartfoxserver.v2.redbox.AVCastManager;
import com.smartfoxserver.v2.redbox.data.LiveCast;
import com.smartfoxserver.v2.redbox.events.RedBoxCastEvent;
import com.smartfoxserver.v2.redbox.events.RedBoxConnectionEvent;
import com.smartfoxserver.v2.requests.CreateRoomRequest;
import com.smartfoxserver.v2.requests.JoinRoomRequest;
import com.smartfoxserver.v2.requests.LoginRequest;
import com.smartfoxserver.v2.requests.PrivateMessageRequest;
import com.smartfoxserver.v2.requests.PublicMessageRequest;
import com.smartfoxserver.v2.requests.RoomPermissions;
import com.smartfoxserver.v2.requests.RoomSettings;
import com.smartfoxserver.v2.requests.buddylist.BuddyMessageRequest;
import com.smartfoxserver.v2.util.ClientDisconnectionReason;

import components.CreateRoomWindow;
import components.EnterPasswordPanel;
import components.PrivateChat;
import components.VideoConferenceItem;

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.StatusEvent;
import flash.geom.Matrix;
import flash.media.Camera;
import flash.media.Video;
import flash.net.NetStream;
import flash.utils.getDefinitionByName;

import flexlib.scheduling.scheduleClasses.utils.Selection;

import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;
import mx.containers.TitleWindow;
import mx.controls.Alert;
import mx.controls.List;
import mx.controls.TextArea;
import mx.core.IFlexDisplayObject;
import mx.core.mx_internal;
import mx.events.CloseEvent;
import mx.graphics.ImageSnapshot;
import mx.managers.PopUpManager;
import mx.states.RemoveChild;
import mx.utils.UIDUtil;

import spark.components.Button;

private const INITIAL_ROOM_NAME:String = "默认房间";

private var sfs:SmartFox;
private var alert:Alert;

private var lastJoinedRoomIndex:int = -1;

public var buddyChatPanelsList:Array;
private var popUp:TitleWindow;


/**
 * Application initialization.
 * An instance of the SmartFoxServer client API is created, and event listeners are added.
 */
private function init():void
{
	sfs = new SmartFox(false);
	
	// Add event listeners
	sfs.addEventListener(SFSEvent.CONFIG_LOAD_FAILURE, onConfigLoadFailure);
	sfs.addEventListener(SFSEvent.CONNECTION, onConnection);
	sfs.addEventListener(SFSEvent.CONNECTION_LOST, onConnectionLost);
	
	
	sfs.addEventListener(SFSEvent.LOGIN_ERROR, onLoginError);
	sfs.addEventListener(SFSEvent.LOGIN, onLogin);
	
	
	sfs.addEventListener(SFSEvent.ROOM_JOIN_ERROR, onRoomJoinError);
	sfs.addEventListener(SFSEvent.ROOM_JOIN, onRoomJoin);
	
	
	sfs.addEventListener(SFSEvent.PUBLIC_MESSAGE, onPublicMessage);
	sfs.addEventListener(SFSEvent.PRIVATE_MESSAGE, onPrivateMessage);
	
	
	
	
	sfs.addEventListener(SFSEvent.USER_ENTER_ROOM, onUserEnterRoom);
	sfs.addEventListener(SFSEvent.USER_EXIT_ROOM, onUserExitRoom);
	
	sfs.addEventListener(SFSEvent.USER_COUNT_CHANGE, onUserCountChange);
	sfs.addEventListener(SFSEvent.ROOM_ADD, onRoomAdd);
	sfs.addEventListener(SFSEvent.ROOM_REMOVE, onRoomRemove);
	sfs.addEventListener(SFSEvent.ROOM_CREATION_ERROR, onRoomCreationError);
	
	
	buddyChatPanelsList = new Array();
	


}
/*Set first tab as non-closable*/
protected function bar_initializeHandler():void
{
	// 
	/*Microscope bar does not need closeBtutton*/
	microscopeBar.setTabClosePolicy(0, false);
	microscopeBar.setTabClosePolicy(1, false);
	microscopeBar.setTabClosePolicy(2, false);
}


/**
 * Login user.
 */
private function login():void
{
	var username:String = loginPanel.ti_username.text;
	var request:LoginRequest = new LoginRequest(username);
	sfs.send(request);
}

/**
 * Join the passed room.
 */
private function joinRoom(roomName:String):void
{
/*	var request:JoinRoomRequest = new JoinRoomRequest(roomName);
	sfs.send(request);*/
	var room:Room = sfs.getRoomByName(roomName);
	
	if (room != null)
	{
		if (room.isPasswordProtected)
		{
			showPopUp(EnterPasswordPanel);
			(popUp as EnterPasswordPanel).roomName = roomName;
		}
		else
		{
			var request:JoinRoomRequest = new JoinRoomRequest(roomName);
			sfs.send(request);
		}
	}
}

/**
 * Join room button click event listener (enter password panel).
 * Join a room using the password entered in the enter password pupup. 
 */
public function onJoinRoomPopuUpBtClick():void
{
	var enterPwdPopUp:EnterPasswordPanel = (popUp as EnterPasswordPanel);
	
	if (enterPwdPopUp.ti_password.text != "")
	{
		// Join room
		var request:JoinRoomRequest = new JoinRoomRequest(enterPwdPopUp.roomName, enterPwdPopUp.ti_password.text);
		sfs.send(request);
		
		// Close popup
		removePopUp();
	}
}

/**
 * Cancel (or X) button click event listener (enter password panel).
 * Select previously joined room in rooms list. 
 */
public function onCancelPopuUpBtClick():void
{
	// Re-select list item corresponding to the last joined room
	selectLastJoinedRoom();
	//ls_rooms.selectedIndex = lastJoinedRoomIndex;
	
	// Close popup
	removePopUp();
}
private function selectLastJoinedRoom():void
{
	// Re-select list item corresponding to the last joined room
	var lastJoinedRoom:Room = sfs.lastJoinedRoom;
	if (lastJoinedRoom != null)
		ls_rooms.selectedIndex = lastJoinedRoomIndex;
}


//---------------------------------
// User interaction event handlers
//---------------------------------

/**
 * Login button click event listener.
 * Establish a connection to SmartFoxServer (if necessary) and perform login.
 */
public function onLoginBtClick():void
{
	// Set login panel state
	loginPanel.isConnecting = true;
	
	// Clear any previous message in the login panel
	loginPanel.ta_error.text = "";
	
	// Check if connection is already available
	// (this can happen in case of login error, for example)
	if (!sfs.isConnected)
	{
		// If this is the first time we are attempting the connection,
		// we have to load the external configuration file containing the connection details (ip, port, zone)
		// We know if this is the first connection by checking the SmartFox.config property (not null if configuration is already loaded)
		if (sfs.config == null)
			sfs.loadConfig("config/sfs-config.xml", true);
		else
			sfs.connect();
	}
	else
		login();
}

/**
 * Disconnect button click event listener.
 * Disconnect from SmartFoxServer.
 */
private function onDisconnectBtClick():void
{
	sfs.disconnect();
}

/**
 * Room list selection change event listener.
 * Join the selected room.
 */
private function onRoomListChange():void
{
	if (ls_rooms.selectedIndex > -1)
	{
		// Join selected room
		joinRoom(ls_rooms.selectedItem.name);
	}
	else
	{
		// Re-select last joined room
		// This is required in case user deselects currently selected item by holding the CMD (Mac) or CTRL (Windows) key
		//ls_rooms.selectedIndex = lastJoinedRoomIndex;
		selectLastJoinedRoom();
	}
}

/**
 * Send public message button click event listener.
 * Send a public message to all users in the room.
 */
private function onSendBtClick():void
{
	if (ti_chatMsg.text.length > 0)
	{
		var request:PublicMessageRequest = new PublicMessageRequest(ti_chatMsg.text);
		sfs.send(request);
		
		ti_chatMsg.text = "";
	}
}



/**
 * Create room button click event listener.
 * Show a popup panel where user can set the room properties.
 */
private function onCreateRoomApplicationBtClick():void
{
/*	createRoomWindow = PopUpManager.createPopUp(this, CreateRoomWindow, true) as CreateRoomWindow;
	PopUpManager.centerPopUp(createRoomWindow);
	createRoomWindow.addEventListener(CloseEvent.CLOSE, onPopUpClosed, false, 0, true);*/
	showPopUp(CreateRoomWindow);

}
private function showPopUp(clazz:Class):void
{
	popUp = PopUpManager.createPopUp(this, clazz, true) as TitleWindow;
	PopUpManager.centerPopUp(popUp);
	popUp.addEventListener(CloseEvent.CLOSE, onPopUpClosed, false, 0, true);
}

/**
 * Create room button click event listener.
 * Create a new room using the parameters entered in the create room pupup. 
 */
public function onCreateRoomPopuUpBtClick():void
{
	
	
	var createRoomPopUp:CreateRoomWindow = (popUp as CreateRoomWindow);
	
	if (createRoomPopUp.ti_name.length > 0)
	{
		// Collect room settings
		var settings:RoomSettings = new RoomSettings(createRoomPopUp.ti_name.text);
		settings.password = createRoomPopUp.ti_password.text;
		settings.maxUsers = createRoomPopUp.ns_maxUsers.value;
		
		// Set permissions
		var permissions:RoomPermissions = new RoomPermissions();
		permissions.allowNameChange = true;
		permissions.allowPasswordStateChange = true;
		permissions.allowPublicMessages = true;
		permissions.allowResizing = true;
		settings.permissions = permissions;
		
		// Create room
		var request:CreateRoomRequest = new CreateRoomRequest(settings, true, sfs.lastJoinedRoom);
		sfs.send(request);
		
		// Close popup
		removePopUp();
	}
}

private function onAlertClosed(evt:Event):void
{
	removeAlert();
}

private function onPopUpClosed(evt:Event):void
{
	removePopUp();
}

//---------------------------------
// SmartFoxServer event handlers
//---------------------------------

/**
 * Unable to load client-side configuration.
 */
private function onConfigLoadFailure(evt:SFSEvent):void
{
	// Set login panel state
	loginPanel.isConnecting = false;
	
	// Show message
	loginPanel.ta_error.text = "Unable to load client configuration file";
}

/**
 * On successful connection established, login user.
 */
private function onConnection(evt:SFSEvent):void
{
	if (evt.params.success)
		login();
	else
	{
		// Set login panel state
		loginPanel.isConnecting = false;
		
		// Show message
		loginPanel.ta_error.text = "Unable to connect to " + sfs.config.host + ":" + sfs.config.port + "\nPlease check the client configuration";
	}
}

/**
 * On connection lost, go back to login panel view and display disconnection error message.
 */
private function onConnectionLost(evt:SFSEvent):void
{
	// If the chat view is currently displayed, clear it
	if (mainView.selectedChild == view_chat)
	{
		// Clear chat area
		ta_chat.htmlText = "";
		
		// Clear rooms list
		ls_rooms.dataProvider = null;
		lastJoinedRoomIndex = -1;
		
		// Clear users list
		ls_users.dataProvider = null;
		
		// Remove create room popup, if any
		removePopUp();
	}
	
	// Remove alert, if displayed
	removeAlert();
	
	// Remove popup, if any
	removePopUp();
	

	
	// Remove listeners added to AVCastManager instance
	if (avCastMan != null)
	{
		avCastMan.removeEventListener(RedBoxConnectionEvent.AV_CONNECTION_INITIALIZED, onAVConnectionInited);
		avCastMan.removeEventListener(RedBoxConnectionEvent.AV_CONNECTION_ERROR, onAVConnectionError);
		avCastMan.removeEventListener(RedBoxCastEvent.LIVE_CAST_PUBLISHED, onLiveCastPublished);
		avCastMan.removeEventListener(RedBoxCastEvent.LIVE_CAST_UNPUBLISHED, onLiveCastUnpublished);
		avCastMan = null;
	}
	
	
	
	// Set login panel state
	loginPanel.isConnecting = false;
	
	// Show disconnection message, unless user chose voluntarily to close the connection
	if (evt.params.reason != ClientDisconnectionReason.MANUAL)
	{
		var msg:String = "Connection lost";
		
		switch (evt.params.reason)
		{
			case ClientDisconnectionReason.IDLE:
				msg += "\nYou have exceeded the maximum user idle time";
				break;
			
			case ClientDisconnectionReason.KICK:
				msg += "\nYou have been kicked";
				break;
			
			case ClientDisconnectionReason.BAN:
				msg += "\nYou have been banned";
				break;
			
			case ClientDisconnectionReason.UNKNOWN:
				msg += " due to unknown reason\nPlease check the server-side log";
				break;
		}
		
		loginPanel.ta_error.text = msg;
	}
	
	// Show login view
	mainView.selectedChild = view_connecting;
}

/**
 * An error occurred during login; go back to login panel and display error message.
 */
private function onLoginError(evt:SFSEvent):void
{
	// Set login panel state
	loginPanel.isConnecting = false;
	
	// Show error message
	loginPanel.ta_error.text = "Unable to login due to the following reason\n" + evt.params.errorMessage + "(code " + evt.params.errorCode + ")";
}

/**
 * On login, show the chat view.
 */
private function onLogin(evt:SFSEvent):void
{
	// Move to chat view, and display user name 
	mainView.selectedChild = view_chat;
	lb_myUserName.text = sfs.mySelf.name;
	
	// Populate rooms list
	populateRoomsList();
	
	// Join the initial room
	joinRoom(INITIAL_ROOM_NAME);
	
	// Initialize AVCastManager
	initializeAV();
}

/**
 * On room join error, show an alert.
 */
private function onRoomJoinError(evt:SFSEvent):void
{
	// Show alert
	showAlert("Unable to join selected room due to the following error: " + evt.params.errorMessage);
	
	// Re-select list item corresponding to the last joined room
	//ls_rooms.selectedIndex = lastJoinedRoomIndex;
	selectLastJoinedRoom();
}

/**
 * On room joined successfully, populate the users list.
 * 
 * IMPORTANT NOTE
 * When a room is joined, the SmartFoxServer API drop the previous Room object from the rooms list
 * and create a new one containing the additional properties a user can see when inside the room (for example non-global room variables).
 * As the ArrayCollections used as dataproviders of the user interface lists contain a reference to the old object,
 * we have to substitute it with the new object passed in the event parameters.
 */
private function onRoomJoin(evt:SFSEvent):void
{
	var room:Room = evt.params.room;
	
	// Show message in the chat area
	showChatMessage("你加入的是 '" + room.name + "'房间", null);
	
	// Set focus on chat message input
	ti_chatMsg.setFocus();
	
	// Substitute the Room object in the rooms list dataprovider
	// Also, select the list item corresponding to joined room and save last joined room index
	var dataProvider:ArrayCollection = ls_rooms.dataProvider as ArrayCollection;
	for each (var r:Room in dataProvider)
	{
		if (r.id == room.id)
		{
			// Update object in dataprovider
			dataProvider.setItemAt(room, dataProvider.getItemIndex(r));
			
			// Select joined room
			ls_rooms.selectedItem = room;
			lastJoinedRoomIndex = ls_rooms.selectedIndex;
			break;
		}
	}
	
	// Populate users list
	populateUsersList(room);
	
	resetVideoConference();
}

/**
 * On public message, show it in the chat area.
 */
private function onPublicMessage(evt:SFSEvent):void
{
	showChatMessage(evt.params.message, evt.params.sender);
}

/**
 * On user count change, update the rooms list.
 */
private function onUserCountChange(evt:SFSEvent):void
{
	ls_rooms.dataProvider.refresh();
}

/**
 * On user entering the current room, show his/her name in the users list.
 */
private function onUserEnterRoom(evt:SFSEvent):void
{
	var user:User = evt.params.user;

	var priavetChat:PrivateChat=buddyChatPanelsList[user.name];
    if(priavetChat!=null)
		priavetChat.removeBuddyChat();
	
	// Add user to list
	var dataProvider:ArrayCollection = ls_users.dataProvider as ArrayCollection;
	dataProvider.addItem(user);
	
	// Show system message
	showChatMessage("用户 " + user.name + " 加入这个房间！", null);
}

/**
 * On user leaving the current room, remove his/her name from the users list.
 */
private function onUserExitRoom(evt:SFSEvent):void
{
	var user:User = evt.params.user;
	var priavetChat:PrivateChat=buddyChatPanelsList[user.name];
	if(priavetChat!=null)
		priavetChat.removeBuddyChat();
    if(user.isItMe){
		for each (var pC:PrivateChat in buddyChatPanelsList){
			pC.removeBuddyChat();
		}
		buddyChatPanelsList.splice(0);

	}
	// We are not interested in the user's own exit event, because that would cause his/her username to be removed from the users list
	// In fact whenever a room is joined, the previous one is left, so we halway receive this event
	if (!user.isItMe)
	{
		// Remove user from list
		var dataProvider:ArrayCollection = ls_users.dataProvider as ArrayCollection;
		dataProvider.removeItemAt(dataProvider.getItemIndex(user));
		dataProvider.refresh();
		
		// Show system message
		showChatMessage("用户 " + user.name + " 离开这个房间！", null);
	}
}

/**
 * On room added, show it in the rooms list.
 */
private function onRoomAdd(evt:SFSEvent):void
{
	var room:Room = evt.params.room;
	var dataProvider:ArrayCollection = ls_rooms.dataProvider as ArrayCollection;
	dataProvider.addItem(room);
}

/**
 * On room removed, remove it from the rooms list.
 */
private function onRoomRemove(evt:SFSEvent):void
{
	var room:Room = evt.params.room;
	var dataProvider:ArrayCollection = ls_rooms.dataProvider as ArrayCollection;
	
	for each (var r:Room in dataProvider)
	{
		if (r.id == room.id)
		{
			dataProvider.removeItemAt(dataProvider.getItemIndex(r));
			break;
		}
	}
}

/**
 * On room creation error, show an alert.
 */
private function onRoomCreationError(evt:SFSEvent):void
{
	// Show alert
	showAlert("Unable to create room due to the following error: " + evt.params.errorMessage);
}

//---------------------------------
// Other methods
//---------------------------------

/**
 * Populate the rooms list.
 */
private function populateRoomsList():void
{
	// Retrive the rooms list
	var roomList:Array = sfs.roomManager.getRoomList();
	
	// Create the rooms list interface component data provider
	// (note: the list makes use of the getRoomLabel function) 
	var dataProvider:ArrayCollection = new ArrayCollection(roomList);
	
	// Apply sorting
	var sort:Sort = new Sort();
	sort.fields = [new SortField("name")];
	dataProvider.sort = sort;
	
	// Assign data provider to rooms list component
	ls_rooms.dataProvider = dataProvider;
	dataProvider.refresh();
}

/**
 * Populate the users list.
 */
private function populateUsersList(room:Room):void
{
	// Retrive the users list
	var userList:Array = room.userList;
	
	// Create the users list interface component data provider
	// (note: the list makes use of the getUserLabel function) 
	var dataProvider:ArrayCollection = new ArrayCollection(userList);
	
	// Apply sorting
	var sort:Sort = new Sort();
	sort.fields = [new SortField("name")];
	dataProvider.sort = sort;
	
	// Assign data provider to users list component
	ls_users.dataProvider = dataProvider;
	dataProvider.refresh();
}
/**
 * Start a chat with the buddy.
 */
private function onUserListChange():void
{
	var isMe:Boolean = (ls_users.selectedIndex > -1 ? (ls_users.selectedItem as User).isItMe : false);
	if (ls_users.selectedIndex > -1 && !isMe)
	{
		// Alert PrivateChat panel
		getBuddyChatPanel(ls_users);
	}
	else
	{
		Alert.show("用不着给自己发信息!");

	}

}

/**
 * Retrieve the buddy chat panel.
 * If not existing, create it.
 */
private function getBuddyChatPanel(ls_users:List):PrivateChat
{
	// Check if private chat with existing user is already in progress
	
	var  privateChatTitleWindow:PrivateChat= buddyChatPanelsList[(ls_users.selectedItem as User).name];
	if (privateChatTitleWindow == null)
	{
		privateChatTitleWindow = new PrivateChat();
		//privateChatTitleWindow.ls_users=ls_users;
		//privateChatTitleWindow.sfs=sfs;
		privateChatTitleWindow.lsUsName=(ls_users.selectedItem as User).name;
		privateChatTitleWindow.title="与"+(ls_users.selectedItem as User).name+"私聊";
		
		// Add panel to display list
		PopUpManager.addPopUp(privateChatTitleWindow,this,false);
		// Set panel position
		randomMovePanel(privateChatTitleWindow);
		// Keep a reference to the panel for later use
		buddyChatPanelsList[(ls_users.selectedItem as User).name] = privateChatTitleWindow;
	}
	
	return privateChatTitleWindow;
}


/**
 * Slightly alter the position of the panel once centered.
 */
private function randomMovePanel(panel:PrivateChat):void
{
	panel.x = Math.round((this.width - 560) / 2);
	panel.y = Math.round((this.height - 366) / 2);
	
	var dx:int = int(Math.random() * 20);
	var dy:int = int(Math.random() * 20);
	var sx:int = Math.random() * 100 > 49 ? 1 : -1;
	var sy:int = Math.random() * 100 > 49 ? -1 : 1;
	
	panel.x += dx * sx;
	panel.y += dy * sy;
}

/**
 * Send private message button click event listener.
 * Send a private message to the selected user.
 */
public function onBuddyMsgSendBtClick(evt:Event):void
{
	var panel:PrivateChat =evt.target.parentDocument as PrivateChat
	var user:User = sfs.userManager.getUserByName(panel.lsUsName);
	if (panel.ti_privateChatMsg.text != "")
	{
		// In private messaging, the sender always receive his/her own message back.
		// In order to be able to know which user the message was addressed to, we need to pass the recipient id in the additional parameters.
		var params:ISFSObject = new SFSObject();
		params.putInt("rId",user.id );
		
		var request:PrivateMessageRequest = new PrivateMessageRequest(panel.ti_privateChatMsg.text, user.id, params);
		sfs.send(request);
		
		
		
		panel.ti_privateChatMsg.text = "";
	}
}

/**
 * On private message, select the sender in user list and show message in the private chat area.
 * 
 * NOTE
 * The private chat system can be highly improved with respect to this example. In fact a mesages queue could be saved for each user,
 * and when a new private message is received, a notification should appear in the users list, without switching to the sender immediately.
 * The SmartFoxBits UserList component implements this improved logic, with a number of additioanl features, so its usage is highly recommended. 
 */
private function onPrivateMessage(evt:SFSEvent):void
{
	var subParams:ISFSObject = evt.params.data;
	
	showPrivateChatMessage(evt.params.message, evt.params.sender, subParams.getInt("rId"));
}

private function showPrivateChatMessage(message:String, sender:User, recipientId:int):void
{
	// Look for the sender in the users list
	// If the current user is the sender, we have to use the recipientId parameter
	
	
	var  privateChatTitleWindow:PrivateChat;
	var userId:int = (sender.isItMe ? recipientId : sender.id);
	
	if (ls_users.selectedIndex == -1 || ls_users.selectedItem.id != userId)
	{
		for each (var u:User in ls_users.dataProvider)
		{
			if (u.id == userId)
			{
				ls_users.selectedItem = u;
				
				privateChatTitleWindow=getBuddyChatPanel(ls_users);
								
				break;
			}
		}
	}
	
	if (ls_users.selectedIndex > -1)
	{
		privateChatTitleWindow=getBuddyChatPanel(ls_users);
		var formattedMsg:String;
		
		if (sender.isItMe)
			formattedMsg = "<b>You say:</b>";
		else{
			formattedMsg = "<b>" + sender.name + " says:</b>";
			privateChatTitleWindow.glowBoolean=true;
		}
		formattedMsg += "<br/>" + message;
		
		
		
		// Display message
		privateChatTitleWindow.ta_privateChat.htmlText += formattedMsg + "<br/>";
		
		// Update vertical scrolling position
		callLater(setChatVPosition, [privateChatTitleWindow.ta_privateChat]);
	}
}





/**
 * Generate label for each room in the list.
 */
private function getRoomLabel(room:Room):String
{
	return room.name + " (" + room.userCount + "/" + room.maxUsers + " users)" + (room.isPasswordProtected ? " *" : "");
}

/**
 * Generate label for each user in the list.
 */
private function getUserLabel(user:User):String
{
	return user.name + (user.isItMe ? " (you)" : "");
}

private function showAlert(message:String):void
{
	// Remove previous alert, if any
	removeAlert()
	
	// Show alert
	//alert = Alert.show(message, "Warning", Alert.OK, null, onAlertClosed);
	alert = Alert.show(message, "错误提示");

}

private function removeAlert():void
{
	if (alert != null)
		PopUpManager.removePopUp(alert);
	
	alert = null;
}

private function removePopUp():void
{
	if (popUp != null)
	{
		popUp.removeEventListener(CloseEvent.CLOSE, onPopUpClosed);
		PopUpManager.removePopUp(popUp);
	}
	
	popUp = null;
}

private function showChatMessage(message:String, user:User):void
{
	var formattedMsg:String;
	
	if (user == null)
	{
		// This is a system message
		formattedMsg = "<i>" + message + "</i>";
	}
	else
	{
		// This is a public message
		if (user.isItMe)
			formattedMsg = "<b>You say:</b>";
		else
			formattedMsg = "<b>" + user.name + " says:</b>";
		
		formattedMsg += "<br/>" + message;
	}
	
	// Display message
	ta_chat.htmlText += formattedMsg + "<br/>";
	// Update vertical scrolling position
	callLater(setChatVPosition, [ta_chat]);
}
/**
 * Set the chat area vertical position.
 */
private function setChatVPosition(target:TextArea):void
{
	target.verticalScrollPosition = target.maxVerticalScrollPosition;
}

//---------------------------------
// dispose Video methods
//---------------------------------
private var avCastMan:AVCastManager;


/**
 * Initialize the AVChatManager instance.
 */
private function initializeAV():void
{
	// Create AVChatmanager instance
	avCastMan = new AVCastManager(sfs, sfs.currentIp, false, true);
	
	avCastMan.addEventListener(RedBoxConnectionEvent.AV_CONNECTION_INITIALIZED, onAVConnectionInited);
	avCastMan.addEventListener(RedBoxConnectionEvent.AV_CONNECTION_ERROR, onAVConnectionError);
	avCastMan.addEventListener(RedBoxCastEvent.LIVE_CAST_PUBLISHED, onLiveCastPublished);
	avCastMan.addEventListener(RedBoxCastEvent.LIVE_CAST_UNPUBLISHED, onLiveCastUnpublished);
}

//---------------------------------------------------------------------
// RedBox AVCastManager event handlers
//---------------------------------------------------------------------

/**
 * Handle A/V connection initialized.
 */
public function onAVConnectionInited(evt:RedBoxConnectionEvent):void
{
	// Nothing to do. Usually we should wait this event before enabling the a/v chat related interface elements.
}

/**
 * Handle A/V connection error.
 */
public function onAVConnectionError(evt:RedBoxConnectionEvent):void
{
	var error:String = "The following error occurred while trying to establish an A/V connection: " + evt.params.errorCode;
	
	// Show alert
	showAlert(error);
}

/**
 * Handle new live cast published by user
 */
public function onLiveCastPublished(evt:RedBoxCastEvent):void
{
	var liveCast:LiveCast = evt.params.liveCast;
	
	trace ("User " + liveCast.username + " published his live cast");
	
	// Subscribe live cast and add to video container
	addLiveCast(liveCast);
}

/**
 * Handle live cast unpublished by user
 */
public function onLiveCastUnpublished(evt:RedBoxCastEvent):void
{
	var liveCast:LiveCast = evt.params.liveCast;
	
	trace ("User " + liveCast.username + " unpublished his live cast");
	
	// When a user unpublishes his live cast, the AVCastManager instance automatically unsubscribes
	// that cast for the current user, so we just have to remove his video from the stage
	
	// Remove item from video container
	videoContainer.removeChild(videoContainer.getChildByName("user_" + liveCast.userId));
}
/**
 * Join video conference
 */
public function onJoinConfBtClick():void
{
	// Retrieve live casts already available
	for each (var liveCast:LiveCast in avCastMan.getAvailableCasts())
	{
		// Subscribe live cast and add to video container
		addLiveCast(liveCast);
	}
	
	// Publish my live cast
	try
	{
		var myStream:NetStream = avCastMan.publishLiveCast(true, true);
		
		if (myStream != null)
		{
			// Attach camera output 
			myVCItem.attachCamera(Camera.getCamera());
			
			mainStack.selectedIndex=1;
			bt_joinConf.enabled = false;
			bt_leaveConf.enabled = true;
		}
	}
	catch (e:Error)
	{
		var error:String = "The following error occurred while trying to subscribe a live cast: " + e.message;
		
		// Show alert
		showAlert(error);
	}
}

/**
 * Leave video conference
 */
public function onLeaveConfBtClick():void
{
	// Stop receiveing cast publish/unpublish notification
	avCastMan.stopPublishNotification();
	
	// Retrieve live casts
	for each (var liveCast:LiveCast in avCastMan.getAvailableCasts())
	{
		// Unsubscribe cast
		avCastMan.unsubscribeLiveCast(liveCast.id);
	}
	
	// Unpublish my live cast
	avCastMan.unpublishLiveCast();
	
	// Reset video conference container
	resetVideoConference();
}










/**
 * Add live cast to video container
 */
private function addLiveCast(liveCast:LiveCast):void
{
	// Subscribe cast
	var stream:NetStream = avCastMan.subscribeLiveCast(liveCast.id);
	
	if (stream != null)
	{
		// Add item to video container
		var item:VideoConferenceItem = new VideoConferenceItem();
		item.name = "user_" + liveCast.userId;
		
		trace("item:"+item.name);
		videoContainer.addChild(item);
		
		// Attach stream to item
		item.setLabelText(liveCast.username);
		item.attachStream(stream);
	}
}

/**
 * Reset video conference container
 */
public function resetVideoConference():void
{
	// Retrieve live casts
	for each (var liveCast:LiveCast in avCastMan.getAvailableCasts())
	{
		// Remove item from video container
/*		var item:VideoConferenceItem = new VideoConferenceItem();
		item.name = "user_" + liveCast.userId;
		trace("item:"+item.name);
		videoContainer.removeElement(item);*/
		videoContainer.removeChild(videoContainer.getChildByName("user_" + liveCast.userId));
	}
	
	// Stop camera output
	myVCItem.reset(sfs.mySelf.name + " (me)");
	
	bt_joinConf.enabled = true;
	bt_leaveConf.enabled = false;
}






/*Dispose camera*/
//定义一个摄像头  
private var camera:Camera; 
//定义一个本地视频  
private var localVideo:Video;   
//定义视频截图  
private var videoBitmapData:BitmapData;   


//初始化摄像头  
private function initCamera():void  
{  
	//打开摄像头  
/*	camera = Camera.getCamera("0");  
	if(camera == null && Camera.names.length <= 0                                                             )  
	{  
		Alert.show("没有找到摄像头，是否重新查找!", "提示", Alert.OK|Alert.NO, this, onInitCamera);  
		return;  
	}  
	
	camera.addEventListener(StatusEvent.STATUS,onCameraStatusHandler);  
	//将摄像头的捕获模式设置为最符合指定要求的本机模式.  
	camera.setMode(1000,550,30);  
	//设置每秒的最大带宽或当前输出视频输入信号所需的画面质量  
	camera.setQuality(144,85);  */ 
	localVideo = new Video();  
	localVideo.width = 1000;  
	localVideo.height = 550; 
	//正在捕获视频数据的 Camera 对象  
	camera = Camera.getCamera();  
	localVideo.attachCamera(camera);  
	cameraVideo.addChild(localVideo);  
	//USB 视频设备  
	trace(Camera.names.length+"");  
	closeCamera.enabled=true;
	openCamera.enabled=false;
	shootingBtn.enabled=true;
}  
//关闭摄像头  
private function closeMyCamera():void  
{  
	camera = Camera.getCamera(null); 
	camera = null; 
	localVideo.attachCamera(null); 
	cameraVideo.removeChild(localVideo);
	closeCamera.enabled=false;
	openCamera.enabled=true;
	shootingBtn.enabled=false;
} 
//检测摄像头权限事件
private function onCameraStatusHandler(event:StatusEvent):void
{
	if(!camera.muted)
	{
		shootingBtn.enabled = true;
	}
	else
	{
		Alert.show("无法链接到活动摄像头，是否重新检测，请充许使用摄像头！", "提示", Alert.OK|Alert.NO, this, onInitCamera);
	}
	camera.removeEventListener(StatusEvent.STATUS, onCameraStatusHandler);
}

//当摄像头不存在，或连接不正常时重新获取
private function onInitCamera(event:CloseEvent):void
{
	if(event.detail == Alert.OK)
	{
		initCamera();
	}
}
//拍照按钮事件，进行视频截图
private function takePicture():void
{
	var bd:BitmapData = ImageSnapshot.captureBitmapData(cameraVideo);
	mainStack.selectedIndex=2;
	menuViewStack.selectedIndex=2;
	image.source = bd;
}	









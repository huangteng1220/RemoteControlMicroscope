package components.customtitlewindow {
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	
	import mx.events.SandboxMouseEvent;
	import mx.managers.CursorManager;
	
	import spark.components.Button;
	import spark.components.TitleWindow;
	import spark.events.TitleWindowBoundsEvent;
	import spark.skins.spark.windowChrome.MaximizeButtonSkin;
	import spark.skins.spark.windowChrome.RestoreButtonSkin;
	
	[SkinState("minimized")]
	
	[SkinState("maximize")]
	
	
	[Event(name="windowResizeStart", type="components.customtitlewindow.CustomTitleWindowEvent")]
	[Event(name="windowResizing", type="components.customtitlewindow.CustomTitleWindowEvent")]
	[Event(name="windowResize", type="components.customtitlewindow.CustomTitleWindowEvent")]
	[Event(name="windowResizeEnd", type="components.customtitlewindow.CustomTitleWindowEvent")]
	
	
	[Event(name="min", type="components.customtitlewindow.CustomTitleWindowEvent")]
	
	[Event(name="max", type="components.customtitlewindow.CustomTitleWindowEvent")]
	
	public class CustomTitleWindow extends TitleWindow {
		
		public static const BOTTOM_RIGHT:String 		= "bottomRight";
		
		
		
		[SkinPart(required="false")]
		public var resizeHandleBR:Button;
		
		
		public var resizeEnabled:Boolean = true;
		public var currentResizeHandle:String;
		public var savedWindowRect:Rectangle;
		public var startResizeBounds:Rectangle;
		private var dragMaxX:Number;
		private var dragMaxY:Number;
		private var dragAmountX:Number;
		private var dragAmountY:Number;
		private var dragStartMouseX:Number;
		private var dragStartMouseY:Number;
		
		public function CustomTitleWindow() {
			super();
		}
		
		
		private var _moveEnabled:Boolean = true;
		public function set moveEnabled(val:Boolean):void {
			if(_moveEnabled != val){
				_moveEnabled = val;
				if(_moveEnabled){
					//remove listener
					removeEventListener(TitleWindowBoundsEvent.WINDOW_MOVE_START, onTitleWindowMoveStart);
				}
				else {
					//add listener so we can intercept move event
					addEventListener(TitleWindowBoundsEvent.WINDOW_MOVE_START, onTitleWindowMoveStart,false,0,true);
				}
				
			}
		}
		public function get moveEnabled():Boolean {
			return _moveEnabled;
		}
		
		protected function onTitleWindowMoveStart(event:TitleWindowBoundsEvent):void {
			if(!moveEnabled){
				event.preventDefault(); //cancel the move
			}
		}
		
		
		protected function resizeHandle_mouseDownHandler(event:MouseEvent):void {
			if(resizeEnabled && enabled){
				currentResizeHandle = resizeHandleForButton(event.target as Button);
				dragStartMouseX = event.stageX;
				dragStartMouseY = event.stageY;
				savePanel();
				dragMaxX = savedWindowRect.x + (savedWindowRect.width - minWidth);
				dragMaxY = savedWindowRect.y + (savedWindowRect.height - minHeight);
				
				var sbRoot:DisplayObject = systemManager.getSandboxRoot();
				
				sbRoot.addEventListener(
					MouseEvent.MOUSE_MOVE, resizeHandle_mouseMoveHandler, true);
				sbRoot.addEventListener(
					MouseEvent.MOUSE_UP, resizeHandle_mouseUpHandler, true);
				sbRoot.addEventListener(
					SandboxMouseEvent.MOUSE_UP_SOMEWHERE, resizeHandle_mouseUpHandler)
				
				// add the mouse shield so we can drag over untrusted applications.
				systemManager.deployMouseShields(true);
			}
		}
		
		protected function resizeHandle_mouseMoveHandler(event:MouseEvent):void {
			
			// Check to see if this is the first windowResize
			if (!startResizeBounds){
				// First dispatch a cancellable "windowResizeStart" event
				startResizeBounds = new Rectangle(x, y, width, height);
				var startEvent:CustomTitleWindowEvent =
					new CustomTitleWindowEvent(CustomTitleWindowEvent.WINDOW_RESIZE_START,
						false, true, startResizeBounds, null);
				dispatchEvent(startEvent);
				
				if (startEvent.isDefaultPrevented()){
					// Clean up code if entire resize is canceled.
					var sbRoot:DisplayObject = systemManager.getSandboxRoot();
					
					sbRoot.removeEventListener(
						MouseEvent.MOUSE_MOVE, resizeHandle_mouseMoveHandler, true);
					sbRoot.removeEventListener(
						MouseEvent.MOUSE_UP, resizeHandle_mouseUpHandler, true);
					sbRoot.removeEventListener(
						SandboxMouseEvent.MOUSE_UP_SOMEWHERE, resizeHandle_mouseUpHandler);
					
					systemManager.deployMouseShields(false);
					
					startResizeBounds = null;
					currentResizeHandle = null;
					CursorManager.removeCursor(CursorManager.currentCursorID);
					return;
				}
			}
			
			//windowResizeStart event was not canceled, so go ahead and start resizing
			dragAmountX = event.stageX - dragStartMouseX;
			dragAmountY = event.stageY - dragStartMouseY;
			
			var beforeBounds:Rectangle = new Rectangle(x, y, width, height);
			var afterBounds:Rectangle = new Rectangle(x, y, width, height);
			
			if(currentResizeHandle == BOTTOM_RIGHT && event.stageX < systemManager.stage.stageWidth && event.stageY < systemManager.stage.stageHeight) {
				afterBounds.width = Math.max(savedWindowRect.width + dragAmountX, minWidth);
				afterBounds.height = Math.max(savedWindowRect.height + dragAmountY, minHeight);
			}
			
			
			
			var e1:CustomTitleWindowEvent =
				new CustomTitleWindowEvent(CustomTitleWindowEvent.WINDOW_RESIZING,
					false, true, beforeBounds, afterBounds);
			dispatchEvent(e1);
			
			// Move and resize only if the windowResizing event is not canceled.
			if (!(e1.isDefaultPrevented())){
				moveAndResize(afterBounds.x,afterBounds.y, afterBounds.width, afterBounds.height);
			}
			
			event.updateAfterEvent();
		}
		
		protected function moveAndResize(xVal:Number, yVal:Number, widthVal:Number, heightVal:Number):void {
			var beforeBounds:Rectangle = new Rectangle(x, y, width, height);
			
			width = widthVal;
			height = heightVal;
			//call validateNow, the window resize appears jerky/choppy without it.
			validateNow();
			x = xVal;
			y = yVal;
			
			var afterBounds:Rectangle = new Rectangle(x, y, width, height);
			var e2:CustomTitleWindowEvent =
				new CustomTitleWindowEvent(CustomTitleWindowEvent.WINDOW_RESIZE,
					false, false, beforeBounds, afterBounds);
			
			dispatchEvent(e2);
		}
		
		protected function resizeHandle_mouseUpHandler(event:Event):void {
			var sbRoot:DisplayObject = systemManager.getSandboxRoot();
			
			sbRoot.removeEventListener(
				MouseEvent.MOUSE_MOVE, resizeHandle_mouseMoveHandler, true);
			sbRoot.removeEventListener(
				MouseEvent.MOUSE_UP, resizeHandle_mouseUpHandler, true);
			sbRoot.removeEventListener(
				SandboxMouseEvent.MOUSE_UP_SOMEWHERE, resizeHandle_mouseUpHandler);
			
			systemManager.deployMouseShields(false);
			
			currentResizeHandle = null;
			
			// Check to see that a resize actually occurred and that the
			// user did not just click on a resize handle
			if (startResizeBounds) {
				// Dispatch "windowResizeEnd" event with the starting bounds and current bounds.
				var endEvent:CustomTitleWindowEvent =
					new CustomTitleWindowEvent(CustomTitleWindowEvent.WINDOW_RESIZE_END,
						false, false, startResizeBounds,
						new Rectangle(x, y, width, height));
				dispatchEvent(endEvent);
				startResizeBounds = null;
				CursorManager.removeCursor(CursorManager.currentCursorID);
			}
			
		}
		protected function savePanel():void {
			savedWindowRect = new Rectangle(x, y, width, height);
		}
		
		private function resizeHandleForButton(button:Button):String {
			if(button == resizeHandleBR)
				return BOTTOM_RIGHT;
			else
				return null;
		}
		
		override protected function partAdded(partName:String, instance:Object):void {
			super.partAdded(partName, instance);
			
			if(instance == resizeHandleBR) {
				
				Button(instance).addEventListener(MouseEvent.MOUSE_DOWN, resizeHandle_mouseDownHandler);
			}else if (instance == minButton)
			{
				minButton.addEventListener(MouseEvent.MOUSE_DOWN, minButton_clickHandler);
			}
			else if (instance == maxButton)
			{
				maxButton.focusEnabled = false;
				maxButton.addEventListener(MouseEvent.CLICK, maxButton_clickHandler);  
			}
		}
		
		override protected function partRemoved(partName:String, instance:Object):void {
			super.partRemoved(partName, instance);
			if( instance == resizeHandleBR) {
				
				Button(instance).removeEventListener(MouseEvent.MOUSE_DOWN, resizeHandle_mouseDownHandler);
			}else 	if (instance == minButton)
				minButton.removeEventListener(MouseEvent.MOUSE_DOWN, minButton_clickHandler);
				
			else if (instance == maxButton)
				maxButton.removeEventListener(MouseEvent.CLICK, maxButton_clickHandler);
			
		}
		
		
		[SkinPart(required="false")] 
		public var minButton:Button;
		
		[SkinPart(required="false")] 
		public var maxButton:Button;
		
		//存储本组件当前的坐标（x、y）和大小（w，h）
		private var currentX:Number ;
		private var currentY:Number ;
		
		private var currentW:Number ;
		private var currentH:Number ;
		
		
		//存储本组件正常的坐标（x、y）和大小（w，h）
		private var normalX:Number ;
		private var normalY:Number ;
		
		private var normalW:Number ;
		private var normalH:Number ;
		
		//存储本组件上当前的窗口状态是否是最小化，
		//为了便于判断最大化窗口的操作(为了业务逻辑添加的辅助标识)
		
		//初始状态
		private var _currentWinState:String="normal";
		
		
		private var isWinExpanded:Boolean = true;
		
		
		//给ResizeTitleWindow添加titleIcon
		[Bindable]
		public var ImagePath:String;
		
		protected function minButton_clickHandler(event:MouseEvent):void
		{
			this.isPopUp=true;

			dispatchEvent(new CustomTitleWindowEvent(CustomTitleWindowEvent.MIN));
			
		}
		
		protected function maxButton_clickHandler(event:MouseEvent):void
		{
			trace("currentWinState:"+currentWinState);
			//this.minButton.enabled = true;
			if(currentWinState=="minimized"||currentWinState=="maximize"){
				this.x=currentX;
				this.y=currentY;
				this.width = currentW ;
				this.height = currentH ;
				this.isPopUp=true;
				currentWinState = "normal";
				this.maxButton.setStyle("skinClass",Class(MaximizeButtonSkin));
			}
			else if(currentWinState=="normal"){
				currentX = this.x ;
				currentY = this.y ;
				currentW = this.width ;
				currentH = this.height;
				this.x = 0;
				this.y = 40;				
				this.width = this.parent.width ;
				this.height = this.parent.height-40;
				this.isPopUp=false;
				currentWinState="maximize";
				this.maxButton.setStyle("skinClass",Class(RestoreButtonSkin));
			}
			
		}
		public function get currentWinState():String
		{
			return _currentWinState;
		}
		
		public function set currentWinState(value:String):void
		{
			_currentWinState = value;
			invalidateSkinState();
			
		}
		override protected function getCurrentSkinState():String
		{
			
			super.getCurrentSkinState();
			
			return currentWinState;
			
		}
	}
}
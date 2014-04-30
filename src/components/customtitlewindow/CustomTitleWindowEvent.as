package components.customtitlewindow {
	import flash.events.Event;
	import flash.geom.Rectangle;
	
	import spark.events.TitleWindowBoundsEvent;
	
	public class CustomTitleWindowEvent extends TitleWindowBoundsEvent {
		
		public static const WINDOW_RESIZE_START:String 			= "windowResizeStart";
		public static const WINDOW_RESIZING:String 				= "windowResizing";
		public static const WINDOW_RESIZE:String 				= "windowResize";
		public static const WINDOW_RESIZE_END:String 			= "windowResizeEnd";
		public static const MAX:String = "max";
		public static const MIN:String = "min";
		
		
		
		
		public function CustomTitleWindowEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, beforeBounds:Rectangle=null, afterBounds:Rectangle=null) {
			super(type, bubbles, cancelable, beforeBounds, afterBounds);
		}
		
		override public function clone():Event {
			return new CustomTitleWindowEvent(type, bubbles, cancelable, beforeBounds, afterBounds);
		}
		
	}
}
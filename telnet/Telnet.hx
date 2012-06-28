package;

import flash.Lib;
import haxe.Timer;

import flash.utils.JSON;

import flash.net.Socket;
import flash.utils.ByteArray;

import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.events.ErrorEvent;
import flash.events.ProgressEvent;

// to create download of profile
//import flash.net.FileReference;

import flash.external.ExternalInterface;

class Telnet {
	
	// character codes we might read from the socket	
	private static inline var CR : Int = 13; // Carriage Return (CR)
	private static inline var LF : Int = 10; // Line Feed (LF)

	private static inline var WILL : Int = 0xFB; // 251 - WILL (option code)
	private static inline var WONT : Int = 0xFC; // 252 - WON'T (option code)
	private static inline var DO : Int   = 0xFD; // 253 - DO (option code)
	private static inline var DONT : Int = 0xFE; // 254 - DON'T (option code)
	private static inline var IAC : Int  = 0xFF; // 255 - Interpret as Command (IAC)

	private static inline var ESC : Int = 0x1B; //escape character
	private static inline var ECHO : Int = 1; // toggle local echo mode?	
	
	public static var _this:  Telnet;
	
    private var _timer : Timer;	

	private var socket : Socket;
	private var bPromptAppend : Bool;
    private var state:Int;
    private var echoMode: Int;
	private var block_buffer : String;
	private var openSpans: Int;
	
	private var container_id : String;
	
    public static function main(){ 
		_this = new Telnet(); 		
	} 

	/* setup timer to check if page is ready, when it is ready run the ready() function */
	public function new() {        
        _timer      = new Timer( 400 );
        _timer.run  = isReady;        
    }
	

    private function isReady() {        
        if( Lib.current.stage != null && Std.is( Lib.current.stage.stageWidth , Int ) ) {
				_timer.stop();                        	
                ready();
		}        
    }

	private function ready() {
		
		container_id = Lib.current.loaderInfo.parameters.container_id;
		socket = new Socket();
		bPromptAppend = false;
		state = 0;
		echoMode = 1;
		block_buffer = "";
		openSpans = 0;

        socket.addEventListener( Event.CONNECT, 
            function(e):Void { if (socket.connected) { msg("connected..."); } else {  msg("unable to connect"); socket.close();} }
        );
        
        socket.addEventListener( Event.CLOSE, 
            function(e):Void {  msg("connection closed..."); socket.close();  }
        );
        
        socket.addEventListener( IOErrorEvent.IO_ERROR, 
            function(e):Void { msg("Unable to connect: socket error"); socket.close(); }
        );
        
        socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, 
            function(e):Void { jsLog(e.toString()); }
        );

        socket.addEventListener( ErrorEvent.ERROR, 
            function(e):Void { jsLog(e.toString()); }
        );
        
        socket.addEventListener( ProgressEvent.SOCKET_DATA, dataHandler);
				
		ExternalInterface.addCallback("sendText",sendText);
		ExternalInterface.addCallback("connect",connect);
		ExternalInterface.addCallback("disconnect",disconnect);			
	//	ExternalInterface.addCallback("saveFile",saveFile);	
			
		
		ExternalInterface.call( "$('#" + container_id + "').telnet", "ready");
	}
	
	
	
	public function connect(server:String, port:Int) : Void {

		// Attempt to connect to remote socket server.
		try {			
			// msg("Trying to connect to " + server + ":" + port);
			socket.connect(server, port);
			jsLog('connected');			
			
		} catch ( e : Dynamic ) {
			// Unable to connect to remote server, display error message and close connection.
			// msg('error : ' +error.message);
			jsLog('connect failed : ' + e.toString());	
			socket.close();

		}

	}

    public function disconnect() : Void {        	        
        if (socket.connected) {						
        	msg("disconnected");        
			socket.close();        
        }
    }
	
	private function closeSpans() : String {
		var rs : String = '';
		while(openSpans-- > 0) rs += '</span>';
		return rs;
	}

    private function dataHandler(event:ProgressEvent):Void {
	
        var n:Int = socket.bytesAvailable;
        var buffer : String =  "";                        
        var line_buffer : String = "";
        /* start with any buffered indent from the last prompt */
        var ansi_line_buffer : String = '';
        
        // Loop through each available byte returned from the socket connection.
        while (--n >= 0) {
            // Read next available byte.
            var b:Int = socket.readUnsignedByte();
            
            switch (state) {
                case 0:
                    // If the current byte is the "Interpret as Command" code, set the state to 1.
                    if (b == IAC) {                        	
                        state = 1;
                    // if the current byte is the escape char set the state and process ansi chars etc
                    } else if (b == ECHO){
                    	if (echoMode == 0) echoMode = 1; else echoMode = 0;
                    } else if (b == ESC) {
                    	state = 3;
                    }
                    // Else, if the byte is not a carriage return, display the character using the msg() method.
                    else {
                    	
                    	var new_char : String;
                    	
                    	// if this char is a linefeed then process the line...                        	
                    	if (b == LF) { 
                    		// output the line in the buffer
                    		msg(ansi_line_buffer);   
                    		
                    		// add this line to the block buffer
                    		if (line_buffer.length > 0)	block_buffer += line_buffer + '\n';                        		                        	
                    		
                    		// reset the line buffers
                    		line_buffer = "";       
                    		ansi_line_buffer = "";                        		
                    		                 		
                    	} else {

                        	// add this char to the line buffer as long as it aint a newline char 
                        	if (b != CR){
                        		line_buffer += String.fromCharCode(b);
								if (b == 60) {
									ansi_line_buffer += '&lt;';
								} else if (b == 62) {
									ansi_line_buffer += '&gt;';
								} else {
									ansi_line_buffer += String.fromCharCode(b);
								}
                        	} 

                    	}
                    	        	
                    }
             			
                    
                case 1:
                    // If the current byte is the "DO" code, set the state to 2.
                    if (b == DO) {                        	
                        state = 2;
                    } else {                        	
                        state = 0;
                    }
                    
                
                // Blindly reject the option.
                case 2:
                    /*
                        Write the "Interpret as Command" code, "WONT" code, 
                        and current byte to the socket and send the contents 
                        to the server by calling the flush() method.
                    */                        
                    socket.writeByte(IAC);
                    socket.writeByte(WONT);
                    socket.writeByte(b);
                    socket.flush();
                    state = 0;
                    
                    
                case 3:
                	/*  Escape char found...
                		-- Process Ansi codes etc 
                	*/
                		
						/* Begin processing of extended esc code */	
						if (String.fromCharCode(b) == '[') {
							buffer = '';								
							state = 4;
							continue;
						} 
						/* reset terminal command */
						else if (String.fromCharCode(b) == 'c'){
							resetTerminal();
						} 
						/* assorted other things that arn't implemented... */
						else if (String.fromCharCode(b) == 'M') jsLog('[Scroll Up]');
						else if (String.fromCharCode(b) == 'D') jsLog('[Scroll Down]');
						else if (String.fromCharCode(b) == 'H') jsLog('[Set Tab]');
						else if (String.fromCharCode(b) == '8') jsLog('[Restore Cursor & Attrs]');
						else if (String.fromCharCode(b) == '7') jsLog('[Save Cursor & Attrs]');
						else if (String.fromCharCode(b) == ')') jsLog('[Font Set G0]');
						else if (String.fromCharCode(b) == '(') jsLog('[Font Set G1]');							
						else jsLog('[unknown escape code : ' + b + ']');                    		                    	                    	     
                    	
                    	state = 0;
                    	
                	
                	
                case 4:
                
                	/* we only like 0-9 and ; to be attached to our commands */
                	if ( (b >= 48 && b <= 57) || b == 59) {
                		buffer += String.fromCharCode(b);                   		
                	} 
                	/* change font color etc */
                	else if (String.fromCharCode(b) == 'm'){                    		
                		//ansi_line_buffer += String.fromCharCode(ESC) + '[' + buffer + 'm';
						
						var bold_mod : Int = 0;
						var class_list : String = '';
						var aBuffer : Array<String> = buffer.split(';');
						
						// resort buffer so that commands (resets and bolds etc) happen before setting colors
						aBuffer.sort(function(x:String,y:String) : Int { return Std.parseInt(x) - Std.parseInt(y); } );
						
						for (code in aBuffer ) {

							var ansiCode : Int = Std.parseInt(code);
							
							if ( ansiCode == 0 ) {
								ansi_line_buffer += closeSpans();
							}

							// bight intensity
							if ( ansiCode == 1) bold_mod = 8;

							// normal or feint intensity
							if ( ansiCode == 2 || ansiCode == 22) bold_mod = 0;

							// underline
							if ( ansiCode == 3) class_list += 'italic ';

							// underline
							if ( ansiCode == 4) class_list += 'uline ';

							// underline
							if ( ansiCode == 5 || ansiCode == 6) class_list += 'blink ';

							// reverse colours
							if ( ansiCode == 7) class_list = 'fg8 bg1';

							// underline
							if ( ansiCode == 9) class_list += 'strikethrough ';


							// FG color change
							if ( ansiCode <= 37 && ansiCode >= 30) class_list += 'fg' + (ansiCode - 29 + bold_mod);

							// BG color change 
							if ( ansiCode <= 47 && ansiCode >= 40) class_list += 'bg' + (ansiCode - 39 + bold_mod);
							
						}
						
						if(class_list.length > 0){
							ansi_line_buffer += '<span class="' + class_list + '">';
							openSpans++;	
						} 
						
                		state = 0;
            		} else {                    
                		// ignoring all ansi codes other than color changes!                    		
                		jsLog('[ansi:' + buffer + String.fromCharCode(b) + ']');                    	
                		state = 0;
                	}
                	
                
                
            }
                    
        }
        
        
       	// do prompt parsing stuff here (leftover stuff in the line buffer = prompt 
       	// make sure prompt is valid...
       	if (ansi_line_buffer != "") {

			// display the prompt
			msg(ansi_line_buffer);
       		
       	 	if ( 	( line_buffer.indexOf('<') > -1 && line_buffer.indexOf('>') > -1) || 
       	 	  		( line_buffer.indexOf('Choice:') > -1 ) || 
       	 	  		( line_buffer.indexOf('Password:') > -1 ) 
       	 	    ){
       			


	           	// parse the block and each line in it (minus prompt)
	           	if (block_buffer.length > 0){

	           		// parse each line in the block
	           		var aLines : Array<String> = block_buffer.split('\n');
	           		for (line_text in aLines) {		           			
						parse_line(line_text);
	           		}		           		

	           		// parse the entire block
	           		parse_block(block_buffer);                      

	           		block_buffer = "";
	           	} 				 				 	

       			// parse the prompt (now we know it's valid)            			           			           			         		
	       		parse_prompt(line_buffer);


				bPromptAppend = false;

			 // this isn't a valid prompt so append the next line onto it				 
       	 	 }  else {           	 	 		           	 	
           	 	bPromptAppend = true;
           	 	// msg("[bad prompt]");	           	 	           	 		           	 	       	 	 
       	 	 }

       	}           	
        
    }

  	public function sendText(text : String) : Void {
		// check aliases for this command before sending to the mud
        var ba:ByteArray = new ByteArray();

		if (socket.connected) {			
        	ba.writeMultiByte(text + "\n", "UTF-8");
			socket.writeBytes(ba);
            socket.flush();
        	if (echoMode == 1) msg( text );        	
		}
                    
    }        
    

	private function jsCall(method:String, param:String="") {
		
		param = param.split("%").join("%25")
		           	 .split("\\").join("%5c")
					 .split("\n").join("\\\\n")
					 .split("\"").join("%22")
					 .split("&").join("%26")
					;
		
		ExternalInterface.call( "$('#" + container_id + "').telnet", "flashBridge", method, param);
		
	}


	// send new line of ansi Text Event (with data)
    public function msg(ansiText:String): Void { 
    	
    	// if the current line is a prompt then append output onto it.
    	if (bPromptAppend) {
			jsCall( "append_line", ansiText + closeSpans());
			bPromptAppend = false;									        	                       
    	} else {
			jsCall( "add_line", ansiText + closeSpans());
    	}

    }
    

    private function parse_prompt(prompt : String) : Void {       		
   		jsCall( "parse_prompt", prompt);
    }
    
    private function parse_line(line: String) : Void {
    	jsCall( "parse_line", line);		
    }
    
    private function parse_block(block: String) : Void {
    	jsCall( "parse_block", block);
    }

    
	public function resetTerminal() : Void {
		jsCall( "reset", "");
	}
	
	

	private function jsLog(text:String) : Void {
		jsCall("log",text);
	}
	
	/* -- requires user interaction. ie need to add an element to the page
	public function saveFile(fn:String, data:String) {
        var ba:ByteArray = new ByteArray();
		var fileReference = new FileReference();
		ba.writeMultiByte(data, "UTF-8");
		fileReference.save(ba,fn);
	}
	*/

 
}
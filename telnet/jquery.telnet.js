(function( $ ){

	var methods = {

		init: function( options ) {

			return this.each(function(){

				var $this = $(this);

				var data = $this.data('telnet');

				// If the plugin hasn't been initialized yet (initial setup/defaults)
				if ( !data ) {
					
					// defaults
					data = {
						port: 23,
						host: window.location.hostname.replace(/www\./i,''),
						commandHistoryLength: 3,
						maxScrollback: 20000
					}
					
					data.output = $('<pre />')
					    .addClass('fg')
						.addClass('bg')					
						.addClass('telnet')
					;
					
					data.input = $('<input type="text" />')
						.addClass('inText')
						.bind('keyup.telnet', methods.inKey)						
					;
					
					data.target = $this;
					
					data.holder = $('<div />')
						.hide()
						.attr('id',$this.attr('id') + '-swfholder' )
					;
					
					data.commandBar = $('<div class="commandBar"></div>');
					
					data.currentLength = 0;					
					data.commandHistory = [];
					data.commandHistoryPos = 0;
					
					// setup
					$this
						.append(data.commandBar)
						.append(data.output)
						.append(data.input)
						.append(data.holder)
						.addClass('telnetContainer')
						.bind('add_line.telnet', methods.add_line)
						.bind('append_line.telnet', methods.append_line)
						.bind('log.telnet', methods.log)
						.bind('reset.telnet', methods.reset)						
					;
					
					$(window).unbind('resize.telnet').bind('resize.telnet',methods.resize_evt);
					
					var flashvars = { container_id: $this.attr('id')};
					var params = { menu: "false", allowScriptAccess: "always", wmode: "transparent" };
					var attributes = {};

					swfobject.embedSWF("telnetBridge.swf", data.holder.attr('id'), "0", "0", "10.0.0","expressInstall.swf", flashvars, params, attributes, function(e){
						data.swf_ref = e.ref;
					});					
					
					$this.data('telnet', data);

					methods.resize.apply(this);
					
					data.input.focus();
					
				} // end of initial setup

				// set any options passed in
				if (options) { $.extend(data, options); }
				
			});
		},		
		
		/* resize all telnets on a window resize event */
		resize_evt: function() {
			$('.telnetContainer').telnet('resize');
		},
		
		resize: function() {
			var data = $(this).data('telnet');
			data.output.outerHeight(data.target.outerHeight() - data.input.outerHeight() - data.commandBar.outerHeight());
		},
		
		ready: function() {
			var data = $(this).data('telnet');			
			data.swf_ref.connect(data.host,data.port);
		},
		
		destroy: function( ) {

			return this.each(function(){

				var $this = $(this);
				var data = $this.data('telnet');

				// Namespacing FTW
				$this.unbind('.telnet');
				data.output.remove();
				$this.removeData('telnet');

			});

		},
	
		// decode string plus use setTimeout to move flash call into it's own thread (flash external interface blocks otherwise)
		flashBridge: function(event,data) {

			var $this = $(this);
			
			data = data.replace(/%22/g, "\"")
			           .replace(/%5c/g, "\\")
			           .replace(/%26/g, "&")
			           .replace(/%25/g, "%");
				
			// console.log(event + ": " + data);
						
			$this.trigger(event, data);

		},
				
		add_line : function(evt, text) {
			var data = $(this).data('telnet'); 
			data.output.append('\n' + text ); 			
			data.currentLength += text.length;
			
			// if we've passed the max scroll back remove the overflow + 20%
			if (data.currentLength > data.maxScrollback ) {
				var rawhtml = data.output.html();
				var newstart = rawhtml.indexOf('\n', data.currentLength - data.maxScrollback + Math.ceil(data.maxScrollback * 0.2) );
				rawhtml = rawhtml.substr(newstart + 1);
				data.currentLength = rawhtml.length;
				data.output.html(rawhtml);
			}
			
			data.output.scrollTop(data.output.prop("scrollHeight"));
		},
				
		append_line : function(evt, text) {
			var data = $(this).data('telnet'); 
			
			data.currentLength += text.length;
			
			data.output.append( text );					
		},		
					
		reset : function(evt, text) { 
			var data = $(this).data('telnet'); 
			data.output.empty();
			data.currentLength = 0; 		
		},
		
		log : function(evt, text) {
			if(window.console){
				console.log( text );
			}
		},

		inKey: function(event) {
			switch (event.which) {
				// enter
				case 13:
					event.preventDefault();

					var $this = $(this).parent();
					var data = $this.data('telnet');				
					var cmd = data.input.val();
				
					// if this command came from the history don't add it to the history
					if (data.commandHistoryPos == 0 || data.commandHistory[data.commandHistory.length - data.commandHistoryPos] != cmd ){
						data.commandHistory.push(cmd);	
					}
				
					data.commandHistoryPos = 0;	
				
				
					if (data.commandHistory.length > data.commandHistoryLength) data.commandHistory = data.commandHistory.slice(1);
				
					// calling sendText so we can pass the correct context (i.e this->parent)			
					methods.sendText.call($this[0],cmd);
					data.input.val('');								
					break;
				
				// up
				// down
				case 38:
				case 40:						
					var data = $(this).parent().data('telnet');
					var cmd = "";					
					// don't go below zero (i.e if they go down from 0, and if they go up from max reset to 0)				
					data.commandHistoryPos = Math.max(0,(data.commandHistoryPos + (39 - event.which) )) % (data.commandHistory.length + 1);
					if (data.commandHistoryPos) {
						cmd = data.commandHistory[data.commandHistory.length - data.commandHistoryPos];
					}				
					data.input.val(cmd);				
					break;		
									
				default:	
					// no-op atm
					
			}
			

		},

		
		sendText : function(text) { 
			var data = $(this).data('telnet');
			data.swf_ref.sendText(text); 			
		}


  };


  $.fn.telnet = function( method ) {  
	if ( methods[method] ) {
	  return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
	} else if ( typeof method === 'object' || ! method ) {
	  return methods.init.apply( this, arguments );
	} else {
	  $.error( 'Method ' +  method + ' does not exist on jQuery.telnet' );
	}	  


  };

})( jQuery );
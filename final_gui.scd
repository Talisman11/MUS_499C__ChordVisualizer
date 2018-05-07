(
/* Global variables to be set by user */
// Window variables
~border = 20;
~window_left = 300;
~window_top = 300;
~window_width = 600;
~window_height = 600;

// Music variables
~root = 61;
~note_radius = 20;
~revolver_radius = 100;
~queue_size = 5; // Arbitrary limit

/* Global variables calculated after user selects values. Should not be modified */
~centerX = ((~window_width - ~border) / 2).round;
~centerY = ((~window_height - ~border) / 2).round;

~gui_queue = [];
~gui_coords = [];

// Create Window for UserView to attach to
Window.closeAll;
w = Window.new("Circle of Chromatics (Starting from C...)", Rect(300, 300, ~window_width, ~window_height))
.front
.alwaysOnTop_(true);

// Create UserView as our canvas
u = UserView.new(w, Rect(~border, ~border, ~window_width - ~border, ~window_height - ~border))
.background_(Color.white)
.resize_(5)
.clearOnRefresh_(false);


// Function that calculates the a note's (x, y) given a note number, based off the "revolver" circle's centerpoint
~polar = {
	arg note=0, bend=0;
	var theta, cx, cy;

	// Calculate the angle for the note (disregard the particular octave)
	theta = (note % 12) * (pi/3) + (bend * (pi/12));

	// Calculate and offset to start at 12 o'clock and go clockwise.
	cx = ~centerX - (~revolver_radius*cos(theta + pi/2));
	cy = ~centerY - (~revolver_radius*sin(theta + pi/2));
	cx@cy;
};

~draw_circle = {
	arg center, radius, border_color, fill_color;

	Pen.addArc(center, radius, 0, 2pi);
	Pen.strokeColor_(border_color);
	Pen.fillColor_(fill_color);
	Pen.fillStroke;
};

// OSCdef to receive Synth signal
OSCdef.new(\recv, {
	arg msg;

	msg.postln;
	{
		// TODO: Since this function draws everything in one frame, need a way to clairvoyantly know what notes to draw
		// all at once. This requires some sort of fixed size binary array using indices and modulo to determine what circles to enable
		// Alternative is a queue that is populated with relevant data within...
		u.drawFunc_({
			arg uv;
			var note, bend, coord, exists;

			exists = false;
			// Pick up data from Synth
			note = msg[3];
			bend = msg[4];

			coord = ~polar.value(note, bend);

			// Scan queue to see if this note already exists
			block {|break|
				(0..~gui_queue.size).do({
					arg i;

					if (~gui_queue[i] == note, {
						exists = true;
						break.value(999); // break from whole block; don't add anything
					});
				});

				if (~gui_queue.size == ~queue_size, {
					~gui_queue.removeAt(0);
					~gui_coords.removeAt(0);
				});
				// Add the note if it does not exists
				if (~gui_queue.size < ~queue_size, {
					~gui_queue.add(note);
					~gui_coords.add(coord);
				});
			};

			// Redraw background, lightly, s.t. previous frame appears to fade like the 'trails', as well as
			// 'revolver' circle
			Pen.fillColor_( Color.gray(0.5, 0.1) );
			Pen.fillRect( Rect( 0, 0, ~window_width, ~window_height ));
			~draw_circle.value(~centerX@~centerY, ~revolver_radius, Color.white, Color(0,0,0,0.1));

			// Draw circles where each note corresponds to a circle on the revolver
			(0..~gui_queue.size-1).do({
				arg i;
				~draw_circle.value(~gui_coords[i], ~note_radius, Color.white, Color(rrand(0.4, 0.6), 0, rrand(0.8, 1.0), 0.4));
			});
		});
		u.refresh;
	}.defer;
}, '/gui');
)

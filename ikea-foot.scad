module ikea_foot() {

    difference() {
	
	union() {	    
	    translate([0, -5, 20/2])		
		cube([135, 30, 10], center = true);	    
	}
	
	union() {
	    
	    translate([1, -5, 20/2])		
		cube([35.5, 10.8, 28], center = true);

	    translate([0, -25, 20/2])		
		cube([110, 15, 28], center = true);

	    translate([0, 20, 20/2])		
		cube([30, 40, 28], center = true);

	    translate([-35.5/4+1, -10.8/2+8.2, 20/2])		
		cube([35.5/2, 10.8, 28], center = true);

	    translate([-50, 21, 20/2])
		rotate(a=[0,0,30])
		   cube([100, 50, 28], center = true);

	    translate([50, 20, 20/2])
		rotate(a=[0,0,-30])
		   cube([100, 50, 28], center = true);

	    translate([50, 30, 20/2])
		cube([100, 50, 28], center = true);

	    translate([21, -5, 20/2])		
		cube([2, 13, 28], center = true);
	}	
    }
}

translate([0, 25, 0])		
    ikea_foot();

translate([0, -25, 0])		
    ikea_foot();



var ndn = new NDN({host: 'localhost'});

function run() {
	var name = new Name(document.getElementById('interest').value);
	var content = ndn.expressInterest(name, new ContentClosure(ndn, name, new Interest(name)), null, function(data){
		// output to 'data' page
	});
	console.log(content);
}

function display() {
	console.log(fullcontent);
}






var appCache = window.applicationCache;

console.log('___________________navigator.onLine', navigator.onLine);

appCache.onUpdateReady = function(){
	console.log('hit appCache.onUpdateReady');
	if(confirm('A new version of NeighborNet is ready.\n\nWould you like to upgrade?')){
		applicationCache.swapCache();
		location.reload();
	}else{
		alert('You chose "no" - the app will not update...');
	}
};

appCache.onnoupdate = function(){
	console.log('No update was ready...')
};

appCache.onprogress = function(){
	console.log('Progressing!!!!!!!!!!!');
};

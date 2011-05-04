// usage:
// filterSelect( selectId, filterId );
//
// <button onClick="filterSelect( 'selectOne', 'filterOne' )"> filter </button>
//
// eugene kuzin, 2007

var metaArray = new Array();
var metaCounter = 0;

var metaHashArray = new Array();

function initSelect( selectId )
{
	var optionsArray = new Array();
	
	var select = document.getElementById( selectId );
	var selectLength = select.length;              
	
	var i = 0;
	
	for( i = 0; i < selectLength; i ++ )
	{
		optionsArray[ i ] = select.options[ i ];
	}
	
	metaArray[ metaCounter ] = optionsArray;
	
	metaHashArray[ metaHashArray.length ] = selectId;
	metaHashArray[ metaHashArray.length ] = metaCounter;
	
	metaCounter ++;
	return metaCounter;
}


function resetSelect( selectId )
{
	var select = document.getElementById( selectId );
	var i = 0;
	var metaIdx = 0;
	
	
	for( i = 0; i < metaHashArray.length; i ++ )
	{
		if( metaHashArray[ i ] == selectId )
		{
			metaIdx = metaHashArray[ i + 1 ];    
		}
	}
	
	for( i = 0; i < metaArray[ metaIdx ].length; i ++ )
	{
		select.options[ i ] = metaArray[ metaIdx ][ i ];
		
	}
	
	return true;
}

function selectInitComplete( selectId )
{
	var found = 0;
	
	for( i = 0; i < metaHashArray.length; i ++ )
	{
		if( metaHashArray[ i ] == selectId )
		{
			found = 1;
		}
	}
	
	return found;
}


function filterSelect( selectId, filterId )
{
	var select = document.getElementById( selectId );
	var entry  = document.getElementById( filterId );
	
	if( !selectInitComplete( selectId ) )
	{
		initSelect( selectId );
	}
	
	resetSelect( selectId );
	
	var filterValue = entry.value;
        
	var i = 0;
	
	while( notInSelect( selectId, filterId ) )
	{
		
		var selectLength = select.length;              
		for( i = 0; i < selectLength; i ++ )
		{
			if( select.options[ i ] )
			{
				var innerString = select.options[ i ].innerHTML;
				
				if( innerString.indexOf( filterValue ) == -1 )
				{
					select.options[ i ] = null;
				}
			}
		}
	}
	return false;
}

function notInSelect( selectId, filterId )
{
	var select = document.getElementById( selectId );
	var entry  = document.getElementById( filterId );
	
	var filterValue = entry.value;
	var selectLength = select.length;              
	var i = 0;
	
	var found = false;
	
	for( i = 0; i < selectLength; i ++ )
        {
		var innerString = select.options[ i ].innerHTML;
		
		if( innerString&& filterValue && innerString.indexOf( filterValue ) == -1 )
                {
			found = true;
                }
        }
	return found;
}

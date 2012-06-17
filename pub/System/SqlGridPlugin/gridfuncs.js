var foswiki; if (!foswiki) foswiki = {};
foswiki.SqlGridPlugin = {};
foswiki.SqlGridPlugin.gridLocalData = {};

foswiki.SqlGridPlugin.myalert = function (msg) {
	var dialog = '<div title="Alert">' + msg + '</div>';
	$(dialog).dialog({
		modal:true,
		resizable: false,
		width: 500,
		buttons: { "Ok": function() { $(this).dialog("close"); } }
	});
}

foswiki.SqlGridPlugin.logDebugMessage = function (gridId, text) {
    var debugDiv = $("#Debug_" + gridId);
    if (debugDiv) {
        debugDiv.append(text + "<br>");
    }
}

foswiki.SqlGridPlugin.showPopup = function (args) {
	var gridId = args.gridId;
	var href = args.popup;
	var popupAction = args.popupAction;
	var debugging = args.debugging;

	var selrow = $('#' + gridId).jqGrid('getGridParam', 'selrow');
	
	if (!selrow && args.requireSelection) {
		foswiki.SqlGridPlugin.myalert('no row selected');
		return false;
	}

	var rowData = selrow ? $('#' + gridId).jqGrid('getRowData', selrow) : [];

	href += ';_grid_id=' + gridId;
	href += ';_selected_row=' + selrow;
	href += ';popupAction=' + encodeURIComponent(popupAction);
	for (var k in rowData) {
		href += ';col_' + k + '=' + encodeURIComponent(rowData[k]);
	}

    if (debugging == "on") {
        foswiki.SqlGridPlugin.logDebugMessage(gridId, href);
    }

	$.get(href, function(content) { 
		var $content = $(content);
        $content.hide();
        $("body").append($content);
        $content.data("autoOpen", true);

        var form = $content.find("form:first");
        var onsubmit = 'return foswiki.SqlGridPlugin.runPopupAction(this, "' + gridId + '", "' + popupAction + '", "' + debugging + '")';
        form.attr('onsubmit', onsubmit);
	})
	.error(function(errObj) {
        foswiki.SqlGridPlugin.myalert(errObj.responseText);
	});
}

foswiki.SqlGridPlugin.runPopupAction = function (form, gridId, popupAction, debugging) {
    var $popup = $(form).closest('.sqlGridDialog');
	var href = popupAction;
	$popup.find(':input').each(function() {
		if (this.name) {
			href += ";" + this.name + "=" + encodeURIComponent(this.value);
		}
	});
    if (debugging == "on") {
        foswiki.SqlGridPlugin.logDebugMessage(gridId, href);
    }
	$.getJSON(href, function(data) {
	    var result = data.actionStatus;
		$popup.dialog("close");
		$('#'+gridId).trigger("reloadGrid");
	    if (result != 200) {
	        foswiki.SqlGridPlugin.myalert(data.message);
	    }
	})
	.error(function(errObj) {
		$popup.dialog("close");
		$('#'+gridId).trigger("reloadGrid");
        foswiki.SqlGridPlugin.myalert(errObj.responseText);
	});
	return false;
}

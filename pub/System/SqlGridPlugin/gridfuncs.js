var foswiki; if (!foswiki) foswiki = {};
foswiki.SqlGridPlugin = {};


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

foswiki.SqlGridPlugin.showForm = function (args) {
	var gridId = args.gridId;
	var href = args.form;
	var formAction = args.formAction;
	var debugging = args.debugging;

	var selrow = $('#' + gridId).jqGrid('getGridParam', 'selrow');
	
	if (!selrow && args.requireSelection) {
		foswiki.SqlGridPlugin.myalert('no row selected');
		return false;
	}

	var rowData = selrow ? $('#' + gridId).jqGrid('getRowData', selrow) : [];

	href += ';_grid_id=' + gridId;
	href += ';_selected_row=' + selrow;
	href += ';formAction=' + encodeURIComponent(formAction);
	for (var k in rowData) {
		href += ';col_' + k + '=' + encodeURIComponent(rowData[k]);
	}

    if (debugging == "on") {
        logDebugMessage(gridId, href);
    }

	$.get(href, function(content) { 
		var $content = $(content);
        $content.hide();
        $("body").append($content);
        $content.data("autoOpen", true);

        var form = $content.find("form:first");
        var onsubmit = 'return foswiki.SqlGridPlugin.runFormAction(this, "' + gridId + '", "' + formAction + '", "' + debugging + '")';
        form.attr('onsubmit', onsubmit);
	})
	.error(function(errObj) {
        foswiki.SqlGridPlugin.myalert(errObj.responseText);
	});
}

foswiki.SqlGridPlugin.runFormAction = function (form, gridId, formAction, debugging) {
    var $popup = $(form).closest('.sqlGridDialog');
	var href = formAction;
	$popup.find(':input').each(function() {
		if (this.name) {
			href += ";" + this.name + "=" + encodeURIComponent(this.value);
		}
	});
    if (debugging == "on") {
        logDebugMessage(gridId, href);
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

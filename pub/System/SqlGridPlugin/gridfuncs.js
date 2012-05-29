function myalert(msg) {
	var dialog = '<div title="Alert">' + msg + '</div>';
	$(dialog).dialog({
		modal:true,
		resizable: false,
		width: 500,
		buttons: { "Ok": function() { $(this).dialog("close"); } }
	});
}

function logDebugMessage(gridId, text) {
    var debugDiv = $("#Debug_" + gridId);
    if (debugDiv) {
        debugDiv.append(text + "<br>");
    }
}

function sqlgrid_showForm(args) {
	var gridId = args.gridId;
	var href = args.form;
	var formAction = args.formAction;
	var debugging = args.debugging;

	var selrow = $('#' + gridId).jqGrid('getGridParam', 'selrow');
	
	if (!selrow && args.requireSelection) {
		myalert('no row selected');
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
        var onsubmit = 'return sqlgrid_runFormAction(this, "' + gridId + '", "' + formAction + '", "' + debugging + '")';
        form.attr('onsubmit', onsubmit);
	})
	.error(function(errObj) {
        myalert(errObj.responseText);
	});
}

function sqlgrid_runFormAction(form, gridId, formAction, debugging) {
    var $popup = $(form).closest('.sqlGridDialog');
	var href = formAction;
	var $inputs = $popup.find(':input');
	$inputs.each(function() {
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
	        myalert(data.message);
	    }
	})
	.error(function(errObj) {
		$popup.dialog("close");
		$('#'+gridId).trigger("reloadGrid");
        myalert(errObj.responseText);
	});
	return false;
}

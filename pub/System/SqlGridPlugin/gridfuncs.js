function myalert(msg) {
	var dialog = '<div title="Alert">' + msg + '</div>';
	$(dialog).dialog({
		modal:true,
		resizable: false,
		buttons: { "Ok": function() { $(this).dialog("close"); } }
	});
}

function sqlgrid_showForm(args) {
	var gridId = args.gridId;
	var href = args.form;
	var formAction = args.formAction;

	var selrow = $('#' + gridId).jqGrid('getGridParam', 'selrow');
	
	if (!selrow && args.requireSelection) {
		myalert('no row selected');
		return false;
	}

	var rowData = selrow ? $('#' + gridId).jqGrid('getRowData', selrow) : [];
//	alert ('selrow ' + selrow);

	href += ';_grid_id=' + gridId;
	href += ';_selected_row=' + selrow;
	href += ';formAction=' + formAction;
	for (var k in rowData) {
		href += ';col_' + k + '=' + encodeURIComponent(rowData[k]);
	}
//		alert(href);

	$.get(href, function(content) { 
		var $content = $(content);

        $content.hide();
        $("body").append($content);
        $content.data("autoOpen", true);

	});

}

function sqlgrid_runFormAction(popup, gridId, formAction) {

//	alert('update time for' + gridId);
//	debugger;
//	var href = sqlPluginObjs[gridId].updateHref;
	var href = formAction;
//	alert(href);
	var $inputs = $(popup).find(':input');
	$inputs.each(function() {
		if (this.name) {
			href += ";" + this.name + "=" + encodeURIComponent(this.value);
		}
	});
//	alert(href);
	$.get(href, function(content) {
	debugger;
		$(popup).dialog("close");
//		$('#'+gridId)[0].clearToolbar();
		$('#'+gridId).trigger("reloadGrid");
	});
}

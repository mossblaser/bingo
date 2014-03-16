class QATable
	constructor: (@tableID) ->
		# Add the table headers
		$("#{@tableID}")
			.append( $("<thead>")
			        .append( $("<tr>")
			                 .append($("<th>").text("Question"))
			                 .append($("<th>").text("Answer")) ))
			.append($("<tbody>"))
		
		@cleanupTable()
		
		return
	
	
	callbacks: []
	onChange: (f)->@callbacks.push(f)
	
	
	cleanupTable: =>
		rowIsEmpty = (row_selector) ->
			isEmpty = true
			for element, index in row_selector.children("td")
				if $.trim($(element).text()) isnt ""
					isEmpty = false
			return isEmpty
		
		# Remove empty entries (except the last line)
		$("#{@tableID} tbody tr:not(:last)")
			.filter(-> rowIsEmpty($(@)))
			.remove()
		
		# Make sure the last row is an empty row
		tableRows = $("#{@tableID} tbody tr:last")
		if tableRows.length == 0 or not rowIsEmpty(tableRows)
			@addEntry("","")
	
	
	addEntry: (question, answer) =>
		$("#{@tableID} tbody")
			.append( $("<tr>")
			        .append( $("<td>")
			                 .attr("contentEditable",true)
			                 .text(question))
			        .append( $("<td>")
			                 .attr("contentEditable",true)
			                 .text(answer))
			.filter("tr").on "blur keyup paste input", =>
				# On entry change
				@cleanupTable()
				for f in @callbacks
					f(@)
				return
		)
		@cleanupTable()
		return this
	
	
	getQAPairs: =>
		for row in $("#{@tableID} tbody tr:not(:last)")
			columns = $(row).children("td")
			{question: $(columns[0]).text(), answer: $(columns[1]).text()}




$ ->
	qaTable = new QATable "#question-table"
	qaTable.onChange((qaTable)->
		console.log(qaTable.getQAPairs())
	)
	
	return

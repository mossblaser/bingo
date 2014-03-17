###
Convert from HSV to RGB
###
hsvToRgb = (h, s, v) ->
	i = Math.floor(h * 6)
	f = h * 6 - i
	p = v * (1 - s)
	q = v * (1 - f * s)
	t = v * (1 - (1 - f) * s)
	switch i % 6
		when 0 then r = v; g = t; b = p;
		when 1 then r = q; g = v; b = p;
		when 2 then r = p; g = v; b = t;
		when 3 then r = p; g = q; b = v;
		when 4 then r = t; g = p; b = v;
		when 5 then r = v; g = p; b = q;
	return {
		r: Math.floor(r * 255)
		g: Math.floor(g * 255)
		b: Math.floor(b * 255)
	}

###
Given a string with alternating lines starting "Q:" and "A:", produces an array
of {question, answer} pairs.
###
parseQAs = (str) ->
	lines = $.trim(str).split(/[\r\n]+/)
	
	for lineNum in [0..lines.length-1] by 2
		if lines.length <= lineNum+1
			throw {message: "Odd number of question/answer pairs.", line:lines[lineNum]}
		
		[q, question] = ($.trim(s) for s in lines[lineNum].split(":",2))
		[a, answer]   = ($.trim(s) for s in lines[lineNum+1].split(":",2))
		
		# Check question/answer prefixes
		if q.toLowerCase() isnt "q"
			throw {message: "Question does not start with 'Q:'", line:lines[lineNum]}
		if a.toLowerCase() isnt "a"
			throw {message: "Answer does not start with 'A:'", line:lines[lineNum+1]}
		
		# Return a list of pairs
		{question: question, answer:answer}



###
Check an array of q/a objects for duplicates. Returns two arrays of array of
arrays of duplicated question/answer indexes, one for duplicate questions, one
for duplicate answers.
###
checkQAs = (qas) ->
	duplicate_questions = []
	duplicate_answers = []
	
	questions = {}
	answers = {}
	for {question, answer}, index in qas
		questions[question] ?= []
		answers[answer] ?= []
		
		if questions[question].length isnt 0 and questions[question] not in duplicate_questions
			duplicate_questions.push(questions[question])
		if answers[answer].length isnt 0 and answers[answer] not in duplicate_answers
			duplicate_answers.push(answers[answer])
		
		questions[question].push(index)
		answers[answer].push(index)
	
	return {
		questions: duplicate_questions
		answers:   duplicate_answers
	}


###
Given a list of {question, answer} pairs and the number of answers per bingo
card, produces a list of answers of that length (or less if not enough questions
are available).

The finishSpeed variable ranges from 1.0 (always pick the first answers) to 0.0
(pick all the answers with similar probability).
###
qaPairToBingoCard = (qaPairs, answersPerCard, finishSpeed=0.6) ->
	allAnswers  = (answer for {answer} in qaPairs)
	cardAnswers = []
	for answerNum in [1..answersPerCard] when allAnswers.length > 0
		# Pick random answers in a top-heavy way which ensures games end relatively
		# quickly
		randAns = 0
		randAns += 1 while Math.random() > 1/(answersPerCard*((1.0-finishSpeed)))
		randAns %= allAnswers.length
		
		# Mark the answer as chosen
		cardAnswers.push(allAnswers[randAns])
		allAnswers.splice(randAns,1)
	
	return cardAnswers


###
Parse & validate the paramter form. On success returns {title, width, height,
numSheets, qas}, on failiure, returns false and provides appropriate error hints.
###
parseParamForm = ->
	# Clear old error messages
	$("#params .has-error").removeClass("has-error")
	$("#params .alert-danger").remove()
	
	# Flag which says if anything went wrong
	failed = false
	
	# Utility function for reporting errors
	reportError = (field, message) ->
		failed = true
		console.log("Something failed", field, message)
		
		# Add error next to field in question
		field
			.parent()
			.addClass("has-error")
			.append(
				$("<p>")
					.addClass("alert")
					.addClass("alert-danger")
					.text(message)
			)
	
	title = $.trim($("#params #title").val())
	if title is ""
		reportError $("#params #title"), "Please enter a title."
	
	
	width = $.trim($("#params #width").val())
	if width is ""
		reportError $("#params #width"), "Please enter a width."
	else if +width < 1
		reportError $("#params #width"), "Please enter a positive width."
	else if +width != Math.floor(width)
		reportError $("#params #width"), "Please enter a whole width."
	width = +width
	
	
	height = $.trim($("#params #height").val())
	if height is ""
		reportError $("#params #height"), "Please enter a height."
	else if +height < 1
		reportError $("#params #height"), "Please enter a positive height."
	else if +height != Math.floor(height)
		reportError $("#params #height"), "Please enter a whole height."
	height = +height
	
	
	numSheets = $.trim($("#params #num-sheets").val())
	if numSheets is ""
		reportError $("#params #num-sheets"), "Please enter a number of sheets."
	else if +numSheets <= 1
		reportError $("#params #num-sheets"), "Please enter a positive number of sheets."
	else if +numSheets != Math.floor(numSheets)
		reportError $("#params #num-sheets"), "Please enter a whole number of sheets."
	numSheets = +numSheets
	
	
	try
		qas = parseQAs $("#params #qas").val()
		
		# Check for duplicates
		{questions, answers} = checkQAs qas
		if questions.length != 0
			throw {
				message: "Question '#{qas[questions[0][0]].question}' used more than once!"
				line: qas[questions[0][0]].question
			}
		if answers.length != 0
			throw {
				message: "Answer '#{qas[answers[0][0]].answer}' used more than once!"
				line: qas[answers[0][0]].answer
			}
	catch err
		reportError $("#params #qas"), err.message
		
		# Select the line in error (if supported by browser)
		textarea = $("#params #qas")[0]
		if textarea.setSelectionRange?
			lineStart = $(textarea).val().indexOf(err.line)
			textarea.setSelectionRange(lineStart, lineStart+err.line.length)
	
	
	finishSpeed = +$("#params #finish-speed").val()
	
	if not failed
		return {
			title: title
			width: width
			height: height
			numSheets: numSheets
			qas: qas
			finishSpeed: finishSpeed
		}
	else
		return false


###
Assigns colours to each bingo card.
###
getCardColour = (num, numSheets) ->
	maxColours = 6
	
	if numSheets <= maxColours
		numColours = numSheets
	else 
		numColours = maxColours
	
	numShades = Math.ceil(numSheets / numColours)
	
	colour = num % numColours
	shade  = Math.floor(num / numColours)
	
	h = (colour/numColours)
	s = 1.0
	v = 0.5 + (((shade+1)/numShades)*0.5)
	
	hsvToRgb(h,s,v)


getCardBadge = (num, numSheets) ->
	{r,g,b} = getCardColour num, numSheets
	
	$("<small>")
		.addClass("bingo-sheet-badge")
		.css("border-color", "rgb(#{r},#{g},#{b})")
		.text(num)


###
Shuffle an array
###
shuffleArray = (arr) ->
	oldArr = arr[..]
	newArr = []
	while oldArr.length > 0
		i = Math.floor(Math.random()*oldArr.length)
		newArr.push(oldArr[i])
		oldArr.splice(i,1)
	
	return newArr


###
Generate a set of bingo cards and identify the question after which the given
card will win.
###
generateBingoCards = (width, height, numSheets, qas, finishSpeed) ->
	for sheetNum in [1..numSheets]
		# Generate this card's answers
		answers = qaPairToBingoCard(qas, width*height, finishSpeed)
		
		# How long before it wins
		unanswered = answers[..]
		for {question,answer}, num in qas
			if answer in unanswered
				unanswered.splice(unanswered.indexOf(answer), 1)
			if unanswered.length == 0
				winningQuestion = num
				break
		
		{answers:answers, winningQuestion:winningQuestion}



###
Generate a set of bingo cards.
###
renderBingoCards = ({title,width,height,numSheets,qas,finishSpeed}) ->
	qas = shuffleArray qas
	
	# Generate the bingo cards
	bingoCards = generateBingoCards(width,height,numSheets,qas, finishSpeed)
	
	# Populate questions and answers table
	$("#bingo-qas-table").children().remove()
	for {question, answer}, num in qas
		winningCards = (index for {winningQuestion}, index in bingoCards when winningQuestion == num)
		$("#bingo-qas-table")
			.append($("<tr>")
				.append($("<td>").text(num+1))
				.append($("<td>").text(question))
				.append($("<td>").text(answer))
				.append($("<td>").append(getCardBadge(n,numSheets) for n in winningCards)))
	
	# Populate bingo cards
	$("#bingo-cards").children().remove()
	for {answers}, index in bingoCards
		# Generate a HTML table for the card
		table = $("<table>")
		for rowNum in [0..height-1]
			row = $("<tr>")
			table.append(row)
			for colNum in [0..width-1]
				answerNum = rowNum*width + colNum
				if answers.length > answerNum
					answer = answers[answerNum]
				else
					answer = " "
				col = $("<td>")
					.text(answer)
				row.append(col)
		$("td", table)
			.css("width", "#{100/width}%")
			.css("text-align", "center")
		
		{r,g,b} = getCardColour index, numSheets
		$("table,th,td", table)
			.css("border-color", "rgb(#{r},#{g},#{b})")
		
		card = $("<div>")
			.addClass("bingo-card")
			.append($("<h1>").addClass("bingo-title"))
			.append(getCardBadge(index,numSheets))
			.append(table)
		$("#bingo-cards").append(card)

	
	# Set all titles
	$(".bingo-title").text(title)



$ ->
	$("#output").hide()
	
	$("#finish-speed")
		.slider()
		.on "slide", (ev) ->
			finishSpeed = +($("#finish-speed").val())
			if finishSpeed > 0.8
				hint = "Everyone ASAP"
			else if finishSpeed > 0.5
				hint = "Fast"
			else if finishSpeed > 0.2
				hint = "Slow"
			else
				hint = "Very Slow"
			$("#finish-speed-hint").text(hint)
	
	# Show results on submit click
	$("#params").submit (event) ->
		event.preventDefault()
		params = parseParamForm()
		if params
			renderBingoCards(params)
			$("#output").show()
		else
			$("#output").hide()
	

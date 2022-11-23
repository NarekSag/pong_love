--[[
    GD50 2018
    Pong Remake

    -- Main Program --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.

    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on 
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

-- size of our actual window
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- [[ paddle properties ]]
-- paddle width
PADDLE_WIDTH = 5
-- paddle height
PADDLE_HEIGHT = 20
-- paddle speed
PADDLE_SPEED = 200

-- [[ ball properties ]]
-- ball width and height
BALL_WIDTH = 4
BALL_HEIGHT = 4

-- enable AI or not, by default AI is disabled
gameMode = 2

-- AI difficulty
AI_DIFFICULTY = 0

-- Keep track of the A key
A_UP = false

-- Keep track of the P key
P_UP = false

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong')

    -- seed the RNG so that calls to random are always random
    math.randomseed(os.time())

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- set up our sound effects; later, we can just index this table and
    -- call each entry's `play` method
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }
    
    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(10, 30, PADDLE_WIDTH, PADDLE_HEIGHT)
    player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, PADDLE_WIDTH, PADDLE_HEIGHT)

    -- place a ball in the middle of the screen
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 4, 4)

    -- initialize score variables
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- player who won the game; not set to a proper value until we reach
    -- that state in the game
    winningPlayer = 0

    -- the state of our game; can be any of the following:
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    gameState = 'start'
end

--[[
    Called whenever we change the dimensions of our window, as by dragging
    out its bottom corner, for example. In this case, we only need to worry
    about calling out to `push` to handle the resizing. Takes in a `w` and
    `h` variable representing width and height, respectively.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Called every frame, passing in `dt` since the last frame. `dt`
    is short for `deltaTime` and is measured in seconds. Multiplying
    this by any changes we wish to make in our game will allow our
    game to perform consistently across all hardware; otherwise, any
    changes we make will be applied as fast as possible and will vary
    across system hardware.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            ball.dx = math.random(140, 200)
        else
            ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if ball:collides(player1) then
            ball.dx = -ball.dx * 1.03
            ball.x = player1.x + 5

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end
        if ball:collides(player2) then
            ball.dx = -ball.dx * 1.03
            ball.x = player2.x - 4

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- -4 to account for the ball's size
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            ball.y = VIRTUAL_HEIGHT - 4
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == 10 then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end

        -- if we reach the right edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player1Score == 10 then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end
    end


    if gameMode == 0 then -- both paddles controlled by AI
        ai_logic(player1)
        ai_logic(player2)
    elseif gameMode == 1 then -- Paddles controlled by Player1 and AI
        player_logic(player1)
        ai_logic(player2)
    else
        player_logic(player1)
        player_logic(player2)
    end

    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

function player_logic(player)
    --
    -- paddles can move no matter what state we're in
    --
    -- check which player it is to set the keyboard values
    if player == player1 then
        upKey = 'w'
        downKey = 's'
    else
        upKey = 'up'
        downKey = 'down'
    end

    -- set player movement logic
    if love.keyboard.isDown(upKey) then
        player.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown(downKey) then
        player.dy = PADDLE_SPEED
    else
        player.dy = 0
    end
end

function ai_logic(player)
    -- get the paddle center
    PADDLE_CENTER = player.y + (PADDLE_HEIGHT / 2)
    -- get the ball center
    BALL_CENTER = ball.y + (BALL_HEIGHT / 2)
    -- set the paddle speed based on the difficulty
    if AI_DIFFICULTY == 0 then
        NEW_PADDLE_SPEED = PADDLE_SPEED / 1.8
    elseif AI_DIFFICULTY == 1 then
        NEW_PADDLE_SPEED = PADDLE_SPEED / 1.5
    elseif AI_DIFFICULTY == 2 then
        NEW_PADDLE_SPEED = PADDLE_SPEED / 1.2
    else
        NEW_PADDLE_SPEED = PADDLE_SPEED
    end

    -- check if the player is on the left side or the right side and set the ball side boolean
    distance = math.abs(player.x - ball.x)
    isBallClose = distance < VIRTUAL_WIDTH / 1.5

    if PADDLE_CENTER < BALL_CENTER and isBallClose then 
            player.dy = NEW_PADDLE_SPEED
        elseif PADDLE_CENTER > BALL_CENTER and isBallClose then
            player.dy = -NEW_PADDLE_SPEED
        else
            player.dy = 0
    end
end

--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'q' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            gameState = 'serve'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    elseif key == 'escape' then
        -- reset the game and go back to main menu
        gameState = 'start'
        ball:reset()
        player1Score = 0
        player2Score = 0
    end

    if gameState == 'start' then
        if key == '0' then
            -- 0 players selected, both paddles controlled by AI
            gameMode = 0
        elseif key == '1' then
            -- 1 player selected, the other paddle is AI
            gameMode = 1
        elseif key == '2' then
            -- 2 players selected, no paddles controlled by AI
            gameMode = 2
        elseif key == 't' then
            -- Change the difficulty
            AI_DIFFICULTY = AI_DIFFICULTY + 1
            if AI_DIFFICULTY > 3 then
                AI_DIFFICULTY = 0
            end
        end
    end
end

--[[
    Called each frame after update; is responsible simply for
    drawing all of our game objects and more to the screen.
]]
function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:apply('start')

    love.graphics.clear(40/255, 45/255, 52/255, 255/255)
    
    -- render different things depending on which part of the game we're in
    if gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 30, VIRTUAL_WIDTH, 'center')
                love.graphics.printf('Press Q to quit!', 0, 40, VIRTUAL_WIDTH, 'center')
        -- display Game mode selection
        displayGameMode()
    elseif gameState == 'serve' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' wins!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    -- show the score before ball is rendered so it can move over the text
    displayScore()
    
    player1:render()
    player2:render()
    ball:render()

    -- display FPS for debugging; simply comment out to remove
    displayFPS()

    -- end our drawing to push
    push:apply('end')
end

--[[
    Simple function for rendering the scores.
]]
function displayScore()
    -- score display
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50,
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end
--[[
    Switch between AI and player2
]]
function displayGameMode()
    love.graphics.setFont(smallFont)
    love.graphics.printf('Press 0,1 or 2 to change the game mode', 0, 20, VIRTUAL_WIDTH, 'center')
    love.graphics.printf('GAME MODE:', 150, 10, VIRTUAL_WIDTH, 'center')
    if gameMode == 0 then
        love.graphics.printf('AI VS AI', 150, 20, VIRTUAL_WIDTH, 'center')
        displayDifficulty()
    elseif gameMode == 1 then
        love.graphics.printf('PLAYER VS AI', 150, 20, VIRTUAL_WIDTH, 'center')
        displayDifficulty()
    else
        love.graphics.printf('PLAYER VS PLAYER', 150, 20, VIRTUAL_WIDTH, 'center')
    end
end
--[[
    Toggle between AI difficulty if AI is enabled
]]
function displayDifficulty()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 1)
    if AI_DIFFICULTY == 0 then
        love.graphics.printf('AI: EASY [PRESS T to Toggle]', 150, 30, VIRTUAL_WIDTH, 'center')
    elseif AI_DIFFICULTY == 1 then
        love.graphics.printf('AI: MEDIUM [PRESS T to Toggle]', 150, 30, VIRTUAL_WIDTH, 'center')
    elseif AI_DIFFICULTY == 2 then
        love.graphics.printf('AI: HARD [PRESS T to Toggle]', 150, 30, VIRTUAL_WIDTH, 'center')
    else
        love.graphics.printf('AI: GOD [PRESS T to Toggle]', 150, 30, VIRTUAL_WIDTH, 'center')
    end
end

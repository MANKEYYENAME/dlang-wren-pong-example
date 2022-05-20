import "core" for Window
import "renderer" for Renderer
import "input" for Input

class Screen {
    static width {800}
    static height {550}
    static barSize {50}
    static introText {
    return """ 
Controls:
    1: Co-op mode
    2: CPU easy
    3: CPU medium
    4: CPU hard
    W: 1 player up
    S: 1 player down
    Up: 2 player up
    Down: 2 player down

Press space to continue
"""
}
}



class Player {
    count {_count}
    count=(a) {_count = a}

    incCount() {
        count = count + 1
    }
    speed {_speed}
    speed=(a) {_speed = a}
    width {50}
    height {200}
    x {_x}
    x=(a) {_x = a}

    y {_y}
    y=(newy) {
        _y = newy.clamp(0, Screen.height - height)
    }

    update(delta, ball) {}

    input(delta, keyUp, keyDown) {
        if(Input.isDown(keyUp)){
            moveUp(delta)
        }
        if(Input.isDown(keyDown)){
            moveDown(delta)
        }
    }

    draw(){
        Renderer.drawRect(_x, _y, width, height)
    }

    moveDown(delta) {
        y = y + delta * _speed
    }

    moveUp(delta) {
        moveDown(-delta)
    }

    setCenter() {
        y = Screen.height / 2 - height / 2 
    }

    construct new() {
        _y = 0
        _x = 0
        _speed = 1
        _count = 0
    }
}

class Ball {
    startSpeed {500}
    speed {_speed}
    speed=(a) {_speed = a}
    radius {30}
    vely {_vely}
    vely=(a) {_vely = a}
    velx {_velx}
    velx=(a) {_velx = a}
    x {_x}
    x=(a) {_x = a}
    y {_y}
    y=(a) {_y = a}

    construct new() {
        _velx = 1
        _vely = 0.5
        reset()
    }

    update(delta, players) {
        for(p in players) {
            checkPlayer(p)
        }
        checkWallY()
        _x = _x + velx * delta * speed
        _y = _y + vely * delta * speed
    }

    draw() {
        Renderer.drawCircle(x, y, radius)
    }

    reset() {
        _x = Screen.width * 0.5
        _y = Screen.height * 0.5
        speed = startSpeed
    }

    checkPlayer(p) {
        var b = p.x < (this.x + this.radius) && p.y < (this.y + this.radius)
        b = b && (p.x + p.width > (this.x - this.radius) && p.y + p.height > (this.y - this.radius))
        if(b) {
            velx = -velx
            if(this.x < p.x) this.x = p.x - radius
            if(this.x > p.x) this.x = p.x + p.width + radius
            speed = speed * 1.02
            p.speed = p.speed * 1.02
        }
    }

    checkWallY() {
        if(y - radius < 0) {
            vely = -vely
            y = radius
        }
        if(y + radius > Screen.height) {
            vely = -vely
            y = Screen.height - radius
        }
    }

}

class Computer is Player {
    construct new(startCD) {
        super()
        _isUp = false
        _isDown = false
        _cd = 0.0
        _startCD = startCD
    }

    input(delta, keyDown, keyUp) {}

    processCD(delta) {
        _cd = _cd - delta
    }

	update(delta, ball) {
        if(_cd >= 0.0) {
            processCD(delta)
            return
        }

		if(ball.y < y + height * 0.5) _isUp = true 
        if(ball.y > y + height * 0.5) _isDown = true
        

        if(_isUp && _isDown) {
            _cd = _startCD
            _isUp = _isDown = false
        }

        if(_isUp) moveUp(delta)
        if(_isDown) moveDown(delta)

        if((y + height*0.5 - ball.y).abs < speed * delta) {
            y = ball.y - height * 0.5
        }

	}
}

class Main {
    startPlayerSpeed {400}

    initPlayer(player, isRight) {
        player.setCenter()
        player.speed = startPlayerSpeed
        if(isRight) {
            player.x = Screen.width - 50 - player.width
        } else {
            _player.x = 50
        }
    }

    construct new() {
        _player = Player.new()
        _player2 = Player.new()
        initPlayer(_player, false)
        initPlayer(_player2, true)
        
        _player2.setCenter()
        _player2.speed = startPlayerSpeed

        _ball = Ball.new()

        _state = Fn.new{|delta| introUpdate(delta)}
    }

    introUpdate(delta) {
        _drawIntro = true
        if(Input.isDown("KEY_SPACE")) {
            _drawIntro = false
            _gameTimer = 0.0
            _state = Fn.new{|delta| gameUpdate(delta)}
        }
    }

    gameUpdate(delta) {
        _gameTimer = _gameTimer + delta
        _ball.update(delta, [_player, _player2])
        _player.update(delta, _ball)
		_player2.update(delta, _ball)
        _player.input(delta, "KEY_W", "KEY_S")
        _player2.input(delta, "KEY_UP", "KEY_DOWN")

        if(_ball.x > Screen.width) {
            reset()
            _player.incCount()
        }
        if(_ball.x < 0) {
            reset()
            _player2.incCount()
        }

        if(Input.isDown("KEY_ONE")) {
            _player2 = Player.new()
            initPlayer(_player2, true)
        }
        if(Input.isDown("KEY_TWO")) {
            _player2 = Computer.new(0.5) 
            initPlayer(_player2, true)
        }
        if(Input.isDown("KEY_THREE")) {
            _player2 = Computer.new(0.25) 
            initPlayer(_player2, true)
        }
        if(Input.isDown("KEY_FOUR")) {
            _player2 = Computer.new(0.1) 
            initPlayer(_player2, true)
        }
    }

    update(delta) {
        _state.call(delta)
    }

    reset() {
        _ball.reset()
        _player.speed = startPlayerSpeed
        _player2.speed = startPlayerSpeed
    }

    start() {
        Window.init(Screen.width, Screen.height + Screen.barSize, "Sample")
    }

    drawVLine(xPos, b) {
        if(b) {
            Renderer.drawRect(xPos, Screen.height, 5, Screen.barSize)
        } else {
            Renderer.drawRect(Screen.width - 5 - xPos, Screen.height, 5, Screen.barSize)
        }
    }

    draw() {
        if(_drawIntro) {
            Renderer.drawText(Screen.introText, Screen.width * 0.5, 60, 20)
        } else {
            _player.draw()
            _player2.draw()
            _ball.draw()
            drawVLine(0, true)
            drawVLine(0, false)
            Renderer.drawText(_player.count.toString, 
                100, 
                Screen.height + Screen.barSize / 2 + 5, 
                Screen.barSize - 10)
            drawVLine(205, true)

            Renderer.drawText(_player2.count.toString, 
                Screen.width - 100, 
                Screen.height + Screen.barSize / 2 + 5, 
                Screen.barSize - 10)
            drawVLine(205, false)
            Renderer.drawText("D|Wren|Raylib pong", 
                Screen.width / 2, 
                Screen.height + Screen.barSize / 2 + 5, 
                Screen.barSize / 2)
            
            Renderer.drawRect(0, Screen.height, Screen.width, 5)
            Renderer.drawText(timerText(), Screen.width * 0.5, 40, 40)
        }

        
    }

    timerText() {
        var mins = (_gameTimer / 60.0).floor.toString
        var secs = (_gameTimer % 60.0).floor.toString
        if(mins.count < 2) mins = "0" + mins
        if(secs.count < 2) secs = "0" + secs
        return mins+":"+secs
    }

    exit(){}
}

var SrlGame = Main.new()
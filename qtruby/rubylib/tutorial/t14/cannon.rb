require 'Qt'
include Math

class CannonField < Qt::Widget
	
	signals	'hit()', 'missed()', 'angleChanged(int)', 'forceChanged(int)', 
			'canShoot(bool)'
	
	slots	'setAngle(int)', 'setForce(int)', 'shoot()', 'moveShot()', 
			'newTarget()', 'setGameOver()', 'restartGame()'
		
	def initialize(parent, name)
		super
		@ang = 45
		@f = 0
		@timerCount = 0;
        @autoShootTimer = Qt::Timer.new( self, 'movement handler' )
        connect( @autoShootTimer, SIGNAL('timeout()'),
                 self, SLOT('moveShot()') )
        @shoot_ang = 0
        @shoot_f = 0
		@target = Qt::Point.new(0, 0)
		@gameEnded = false
		@barrelPressed = false    	
		setPalette( Qt::Palette.new( Qt::Color.new( 250, 250, 200) ) )
		newTarget()
		@barrelRect = Qt::Rect.new(33, -4, 15, 8)
	end

	def angle() 
		return @ang 
	end
    
	def force() 
		return @f 
	end
    
	def gameOver() 
		return @gameEnded 
	end

	def setAngle( degrees )
		if degrees < 5
			degrees = 5
		elsif degrees > 70
        	degrees = 70
		end
		if @ang == degrees
			return
		end
		@ang = degrees
		repaint( cannonRect(), false )
		emit angleChanged( @ang )
	end
	
	def setForce( newton )
		if newton < 0
			newton = 0
		end
		if @f == newton
			return
		end
		@f = newton
		emit forceChanged( @f )
	end
	
	def shoot()
		if isShooting()
			return
		end
		@timerCount = 0
		@shoot_ang = @ang
		@shoot_f = @f
		@autoShootTimer.start( 50 )
		emit canShoot( false )
	end

    @@first_time = true
	
	def newTarget()
		if @@first_time
			@@first_time = false
        	midnight = Qt::Time.new( 0, 0, 0 )
        	srand( midnight.secsTo(Qt::Time.currentTime()) )
		end
		r = Qt::Region.new( targetRect() )
		@target = Qt::Point.new( 200 + rand(190),
                     10  + rand(255) )
		repaint( r.unite( Qt::Region.new(targetRect()) ) )
	end
	
	def setGameOver()
		if @gameEnded
			return
		end
		if isShooting()
			@autoShootTimer.stop()
		end
		@gameEnded = true
		repaint()
	end

	def restartGame()
		if isShooting()
			@autoShootTimer.stop()
		end
		@gameEnded = false
		repaint()
		emit canShoot( true )
	end
	
	def moveShot()
		r = Qt::Region.new( shotRect() )
		@timerCount += 1

		shotR = shotRect()

		if shotR.intersects( targetRect() ) 
			@autoShootTimer.stop()
        	emit hit()
			emit canShoot(true)
 		elsif shotR.x() > width() || shotR.y() > height() ||
                    shotR.intersects(barrierRect()) 
			@autoShootTimer.stop()
			emit missed()
			emit canShoot(true)
		else
			r = r.unite( Qt::Region.new( shotR ) )
		end
		
		repaint( r )
	end

	def mousePressEvent( e )
		if e.button() != Qt.LeftButton
        	return
		end
		if barrelHit( e.pos() )
			@barrelPressed = true
		end
	end

	def mouseMoveEvent( e )
		if !@barrelPressed
			return
		end
		pnt = e.pos();
		if pnt.x() <= 0
			pnt.setX( 1 )
		end
		if pnt.y() >= height()
			pnt.setY( height() - 1 )
		end
		rad = atan2((rect().bottom()-pnt.y()), pnt.x())
		setAngle( ( rad*180/3.14159265 ).round )
	end

	def mouseReleaseEvent( e )
		if e.button() == Qt.LeftButton
			barrelPressed = false;
		end
	end

	def paintEvent( e )
		updateR = e.rect()
		p = Qt::Painter.new( self )

		if @gameEnded
			p.setPen( black )
			p.setFont( Qt::Font.new( 'Courier', 48, Qt::Font.Bold ) )
			p.drawText( rect(), Qt.AlignCenter, 'Game Over' )
		end
		if updateR.intersects( cannonRect() )
			paintCannon( p )
		end
		if updateR.intersects( barrierRect() )
			paintBarrier( p )
		end		
		if isShooting() && updateR.intersects( shotRect() )
			paintShot( p )
		end		
		if !@gameEnded && updateR.intersects( targetRect() )
			paintTarget( p )
		end
		
		p.end()
	end

	def paintShot( p )
		p.setBrush( black )
		p.setPen( Qt.NoPen )
		p.drawRect( shotRect() )
	end

	def paintTarget( p )
		p.setBrush( red )
		p.setPen( black )
		p.drawRect( targetRect() )
	end
	
	def paintBarrier( p )
        p.setBrush( yellow )
        p.setPen( black )
        p.drawRect( barrierRect() )
	end
	
	def paintCannon(p)				
		cr = cannonRect()
		pix = Qt::Pixmap.new( cr.size() )
		pix.fill( self, cr.topLeft() )
		
		tmp = Qt::Painter.new( pix )
		tmp.setBrush( blue )
		tmp.setPen( Qt.NoPen )
		
		tmp.translate( 0, pix.height() - 1 )
		tmp.drawPie( Qt::Rect.new(-35, -35, 70, 70), 0, 90*16 )
		tmp.rotate( - @ang )
		tmp.drawRect( @barrelRect )
		tmp.end()
		
		p.drawPixmap(cr.topLeft(), pix )		
	end

	def cannonRect()
		r = Qt::Rect.new( 0, 0, 50, 50)
		r.moveBottomLeft( rect().bottomLeft() )
		return r
	end
	
	def shotRect()
		gravity = 4.0

		time      = @timerCount / 4.0
		velocity  = @shoot_f
		radians   = @shoot_ang*3.14159265/180.0

		velx      = velocity*cos( radians )
		vely      = velocity*sin( radians )
		x0        = ( @barrelRect.right()  + 5.0 )*cos(radians)
		y0        = ( @barrelRect.right()  + 5.0 )*sin(radians)
		x         = x0 + velx*time
		y         = y0 + vely*time - 0.5*gravity*time*time

		r = Qt::Rect.new( 0, 0, 6, 6 );
		r.moveCenter( Qt::Point.new( x.round, height() - 1 - y.round ) )
		return r
	end

	def targetRect()
		r = Qt::Rect.new( 0, 0, 20, 10 )
		r.moveCenter( Qt::Point.new(@target.x(),height() - 1 - @target.y()) )
		return r
	end
	
	def barrierRect()
        return Qt::Rect.new( 145, height() - 100, 15, 100 )
	end

	def barrelHit( p )
        mtx = Qt::WMatrix.new
        mtx.translate( 0, height() - 1 )
        mtx.rotate( - @ang )
        mtx = mtx.invert()
        return @barrelRect.contains( mtx.map(p) )
    end

 	def isShooting()
		return @autoShootTimer.isActive()
	end

	def sizePolicy()
    	return Qt::SizePolicy.new( Qt::SizePolicy.Expanding, Qt::SizePolicy.Expanding )
	end
end

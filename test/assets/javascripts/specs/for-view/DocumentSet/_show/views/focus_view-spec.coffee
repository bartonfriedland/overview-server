require [
  'jquery'
  'for-view/DocumentSet/_show/models/observable'
  'for-view/DocumentSet/_show/views/focus_view'
], ($, observable, FocusView) ->
  Event = $.Event

  class MockFocus
    observable(this)

    constructor: () ->
      @zoom = 1
      @pan = 0

  describe 'views/focus_view', ->
    describe 'FocusView', ->
      HANDLE_WIDTH=10
      div = undefined
      focus = undefined
      view = undefined

      beforeEach ->
        div = $('<div style="position:relative;width:100px;height:12px;"></div>')[0]
        focus = new MockFocus()

      afterEach ->
        view = undefined
        focus = undefined
        $(div).remove() # Removes all callbacks
        div = undefined
        $('#mousemove-handler').remove()
        $(document).off('.focus-view')
        $(window).off('.focus-view')

      num = (s) -> parseFloat(s)

      mouse_event = (left_or_right_or_body, name, x, y) ->
        $handle = if left_or_right_or_body == 'left'
          $(div).find('.handle.left')
        else if left_or_right_or_body == 'right'
          $(div).find('.handle.right')
        else if left_or_right_or_body == 'middle'
          $(div).find('.middle')
        else
          $('body')

        position = $handle.position()
        e = Event(name)
        e.which = 1
        e.pageX = x
        e.pageY = y
        $handle.trigger(e)

      describe 'starting at (1 0)', ->
        beforeEach ->
          view = new FocusView(div, focus, {
            handle_width: HANDLE_WIDTH
          })

        it 'should add handles at the edges and a middle', ->
          $handle1 = $(div).find('.handle.left')
          $handle2 = $(div).find('.handle.right')
          $middle = $(div).find('.middle')
          expect($handle1.length).toEqual(1)
          expect($handle2.length).toEqual(1)
          expect($middle.length).toEqual(1)
          expect(num($handle1.css('left'))).toEqual(0)
          expect(num($handle2.css('left')) + $handle2.outerWidth()).toEqual(100)
          expect(num($middle.css('left'))).toEqual(0)
          expect(num($middle.css('width'))).toEqual(100)

        it 'should update when zoom changes', ->
          spyOn(view, 'update')
          focus._notify('zoom', 1)
          expect(view.update).toHaveBeenCalled()

        it 'should update when pan changes', ->
          spyOn(view, 'update')
          focus._notify('pan', 0)
          expect(view.update).toHaveBeenCalled()

        it 'should update when the window resizes', ->
          spyOn(view, 'update')
          $(window).trigger('resize')
          expect(view.update).toHaveBeenCalled()

        it 'should center handles that are not at edges', ->
          focus.zoom = 0.25
          focus.pan = 0.25
          view.update()
          $handle1 = $(div).find('.handle.left')
          $handle2 = $(div).find('.handle.right')
          $middle = $(div).find('.middle')
          expect($middle.width()).toEqual(25)
          expect(num($handle1.css('left')) + $handle1.outerWidth() / 2).toEqual(num($middle.css('left')))
          expect(num($handle2.css('left')) + $handle2.outerWidth() / 2).toEqual(num($middle.css('left')) + $middle.width())

        it 'should ensure HANDLE_WIDTH px between the edges', ->
          # See https://github.com/overview/overview-server/issues/266
          focus.zoom = 0.00000001
          focus.pan = 0
          view.update()
          $handle1 = $(div).find('.handle.left')
          $handle2 = $(div).find('.handle.right')
          $middle = $(div).find('.middle')
          expect(num($handle1.css('left')) + $handle1.outerWidth()).toBeCloseTo(50 - HANDLE_WIDTH * 0.5, 4)
          expect($middle.width()).toEqual(HANDLE_WIDTH)
          expect(num($handle2.css('left'))).toBeCloseTo(50 + HANDLE_WIDTH * 0.5, 4)

        it 'should signal when a handle is dragged', ->
          focus.zoom = 0.5
          focus.pan = 0
          view.update()
          zoom = undefined
          pan = undefined
          view.observe('zoom-pan', (o) -> zoom = o.zoom; pan = o.pan)
          mouse_event('left', 'mousedown', 2, 5)
          mouse_event('body', 'mousemove', 12, 5) # 10 pixels to the right
          expect(zoom).toBeCloseTo(0.4)
          expect(pan).toBeCloseTo(0.05)

        it 'should allow dragging past the other handle', ->
          focus.zoom = 0.5
          focus.pan = 0
          # x1 25, x2 75
          view.update()
          zoom = undefined
          pan = undefined
          view.observe('zoom-pan', (o) -> zoom = o.zoom; pan = o.pan)
          mouse_event('right', 'mousedown', 62, 5)
          mouse_event('body', 'mousemove', 2, 5) # 60 pixels to the left
          # x1 15, x2 25
          expect(zoom).toBeCloseTo(0.1)
          expect(pan).toBeCloseTo(-0.3)

        it 'should signal when the bar is dragged', ->
          focus.zoom = 0.25 # anything
          focus.pan = 0
          view.update()
          zoom = undefined
          pan = undefined
          view.observe('zoom-pan', (o) -> zoom = o.zoom; pan = o.pan)
          mouse_event('middle', 'mousedown', 50, 5)
          mouse_event('body', 'mousemove', 15, 5) # 35 pixels to the left -- 35% of the view
          expect(zoom).toEqual(0.25) # unchanged
          expect(pan).toEqual(-0.35)
define [
  'jquery'
  'underscore'
  '../models/observable'
  '../models/drawable_node'
  '../models/color_table'
  'jquery.mousewheel' # to catch the 'mousewheel' event properly
], ($, _, observable, DrawableNode, ColorTable) ->
  DEFAULT_OPTIONS = {
    color: {
      background: '#ffffff',
      line: '#888888',
      line_selected: '#000000',
      line_default: '#333333',
      line_faded: '#999999',
    },
    connector_line_width: 1, # px
    node_line_width: 2, # px
    node_line_width_selected: 4, # px
    node_line_width_leaf: 1, # px
    start_fade_width: 10 #px begin fade to leaf color if node is narrower than this at current zoom
    mousewheel_zoom_factor: 1.2,
  }

  MIN_PAN_DISTANCE = 3 # px. if the user clicks and moves less than this, do not pan.

  HOVER_NODE_TEMPLATE = _.template("""
    <div class="inner">(<%- node.doclist.n.toLocaleString() %>) <%- node.description %></div>
  """)

  class DrawOperation
    constructor: (@canvas, @tree, @tag_id_to_color, @focus_tagids, @focus_nodes, @focus, @options) ->
      $canvas = $(@canvas)
      @width = +Math.ceil($canvas.parent().width())
      @height = +Math.ceil($canvas.parent().height())

      @canvas.width = @width
      @canvas.height = @height

      @ctx = @canvas.getContext('2d')

      # HDPI stuff: http://www.html5rocks.com/en/tutorials/canvas/hidpi/
      device_pixel_ratio = window.devicePixelRatio || 1
      backing_store_ratio = @ctx.webkitBackingStorePixelRatio ||
                            @ctx.mozBackingStorePixelRatio ||
                            @ctx.msBackingStorePixelRatio ||
                            @ctx.oBackingStorePixelRatio ||
                            @ctx.backingStorePixelRatio ||
                            1

      @device_to_backing_store_ratio = ratio = device_pixel_ratio / backing_store_ratio
      if ratio != 1
        old_width = @canvas.width
        old_height = @canvas.height

        @canvas.width = old_width * ratio
        @canvas.height = old_height * ratio

        @canvas.style.width = "#{old_width}px"
        @canvas.style.height = "#{old_height}px"

        @ctx.scale(ratio, ratio)

      @ctx.lineStyle = @options.color.line
      @ctx.font = "12px Helvetica, Arial, sans-serif"
      @ctx.textBaseline = 'top'
      @ctx.shadowColor = 'white'

    clear: () ->
      @ctx.fillStyle = @options.color.background
      @ctx.fillRect(0, 0, @width, @height)
      @root = undefined # will be overwritten if the tree isn't empty

    _auto_fit_pan: (drawable_node) ->
      if @focus_nodes?.length
        nodes = @focus_nodes

        # left_bound, right_bound: absolute X coordinates which must be in view
        left_bound = undefined
        right_bound = undefined
        @root.walk (dn) ->
          if nodes.indexOf(dn.animated_node.node.id) != -1
            # We want the outer bounds--that is, the bounds of the selected node
            # and its children.
            a = dn.absolute_position()
            width = dn.outer_width()
            node_left_bound = a.hmid - width * 0.5
            node_right_bound = a.hmid + width * 0.5

            left_bound = node_left_bound if !left_bound? || node_left_bound < left_bound
            right_bound = node_right_bound if !right_bound? || node_right_bound > right_bound

        if left_bound? && right_bound?
          # left_pan, right_pan: same, but as "focus" coordinates (from -0.5 to 0.5)
          tree_width = @root.outer_width()
          left_pan = left_bound / tree_width - 0.5
          right_pan = right_bound / tree_width - 0.5
          @focus.auto_fit_pan(left_pan, right_pan)

    draw: () ->
      this.clear()
      return if !@tree.root?

      @root = new DrawableNode(@tree.root)
      @_auto_fit_pan()

      px_per_hunit = @width / @root.outer_width() / @focus.zoom
      px_per_vunit = @height / @root.outer_height() # zoom doesn't affect Y axis
      pan_units = @root.outer_width() * (0.5 + @focus.pan - @focus.zoom * 0.5)

      # Set _px objects on all nodes
      @root.px(px_per_hunit, px_per_vunit, pan_units, 0)

      @root.walk(this._draw_single_node.bind(this))

    pixel_to_drawable_node: (x, y) ->
      drawable_node = undefined
      @root?.walk (dn) ->
        return if drawable_node?
        px = dn._px
        if x >= px.left && x <= px.left + px.width && y >= px.top && y <= px.top + px.height
          drawable_node = dn
      drawable_node

    pixel_to_action: (x, y) ->
      drawable_node = @pixel_to_drawable_node(x, y)
      return undefined if !drawable_node?
      animated_node = drawable_node.animated_node

      px = drawable_node._px

      event = if px.width > 20 && x > px.hmid - 5 && x < px.hmid + 5 && y > px.top + px.height - 12 && y < px.top + px.height - 2
        if drawable_node.children()?.length
          'collapse'
        else if !animated_node.loaded
          'expand'
        else
          'click'
      else
        'click'

      return { event: event, id: drawable_node.animated_node.node.id }

    # simple RGB space color interpolator. Returns a when t=0, b when t=1
    _lerp_hexcolor: (a, b, t) ->
      a_red   = parseInt(a.substring(1,3),16)
      a_green = parseInt(a.substring(3,5),16)
      a_blue  = parseInt(a.substring(5,7),16)
      b_red   = parseInt(b.substring(1,3),16)
      b_green = parseInt(b.substring(3,5),16)
      b_blue  = parseInt(b.substring(5,7),16)

      red   = Math.round(t*b_red + (1-t)*a_red)
      green = Math.round(t*b_green + (1-t)*a_green)
      blue  = Math.round(t*b_blue + (1-t)*a_blue)

      "#" + ("0" + red.toString(16)).slice(-2) + ("0" + green.toString(16)).slice(-2) + ("0" + blue.toString(16)).slice(-2)

    _animated_node_to_line_width: (animated_node) ->
      if animated_node.selected
        @options.node_line_width_selected
      else if animated_node.children?.length is 0 # leaf node
        @options.node_line_width_leaf
      else
        @options.node_line_width

    # choose color to draw node outline. selected has its own color, leaf nodes are faded, 
    # and we also fade normal nodes when they get too narrow
    _drawable_node_to_line_color: (drawable_node) ->
      animated_node = drawable_node.animated_node
      if animated_node.selected
        @options.color.line_selected
      else if animated_node.children?.length is 0 # leaf node
        @options.color.line_faded
      else
        if drawable_node._px.width >= @options.start_fade_width
          @options.color.line_default
        else if drawable_node._px.width <= @px_per_hunit  # leaf node width
          @options.color.line_faded
        else
          t = (@options.start_fade_width - drawable_node._px.width) / (@options.start_fade_width - @px_per_hunit)
          this._lerp_hexcolor(@options.color.line_default, @options.color.line_faded, t)

    _draw_tagcount: (left, top, width, height, color, fraction) ->
      return if fraction == 0

      slant_offset = height / 2
      tagwidth = 1.0 * (width + slant_offset) * fraction

      ctx = @ctx

      ctx.save()

      ctx.beginPath()
      ctx.rect(left, top, width, height)
      ctx.clip()

      ctx.fillStyle = color

      ctx.beginPath()
      ctx.moveTo(left, top)
      ctx.lineTo(left + tagwidth + slant_offset, top)
      ctx.lineTo(left + tagwidth - slant_offset, top + height)
      ctx.lineTo(left, top + height)
      ctx.fill()

      ctx.restore()

    _maybe_draw_description: (drawable_node) ->
      px = drawable_node._px
      width = px.width - 6 # border+padding
      return if width < 15

      node = drawable_node.animated_node.node
      description = node.description

      return if !description

      ctx = @ctx

      left = px.left + 3
      right = left + width

      whiteGradient = ctx.createLinearGradient(left, 0, right, 0)
      whiteGradient.addColorStop((width-10)/width, 'rgba(255, 255, 255, 0.85)')
      whiteGradient.addColorStop(1, 'rgba(255, 255, 255, 0)')

      gradient = ctx.createLinearGradient(left, 0, right, 0)
      gradient.addColorStop((width-10)/width, 'rgba(0, 0, 0, 1)')
      gradient.addColorStop(1, 'rgba(0, 0, 0, 0)')

      ctx.save()
      ctx.beginPath()
      ctx.rect(left, px.top, width, px.height)
      ctx.clip()
      ctx.shadowBlur = 3 # ctx.shadowColor is white
      # Build a white background for the text
      ctx.fillStyle = whiteGradient
      ctx.fillText(description, left, px.top + 3)
      ctx.fillText(description, left, px.top + 3) # for stronger shadow
      # And draw black on it
      ctx.fillStyle = gradient
      ctx.fillText(description, left, px.top + 3)
      ctx.restore()

    _maybe_draw_collapse: (drawable_node) ->
      if drawable_node.children()?.length
        px = drawable_node._px
        if px.width > 20
          ctx = @ctx
          y = px.top + px.height - 8
          x = px.hmid
          ctx.lineWidth = 1
          ctx.strokeStyle = '#aaaaaa'
          ctx.beginPath()
          ctx.arc(x, y, 5, 0, Math.PI*2, true)
          ctx.moveTo(x - 3, y)
          ctx.lineTo(x + 3, y)
          ctx.stroke()

    _maybe_draw_expand: (drawable_node) ->
      if !drawable_node.animated_node.loaded
        px = drawable_node._px
        if px.width > 20
          ctx = @ctx
          y = px.top + px.height - 8
          x = px.hmid
          ctx.lineWidth = 1
          ctx.strokeStyle = '#aaaaaa'
          ctx.beginPath()
          ctx.arc(x, y, 5, 0, Math.PI*2, true)
          ctx.moveTo(x - 3, y)
          ctx.lineTo(x + 3, y)
          ctx.moveTo(x, y + 3)
          ctx.lineTo(x, y - 3)
          ctx.stroke()

    _draw_single_node: (drawable_node) ->
      px = drawable_node._px
      animated_node = drawable_node.animated_node
      node = animated_node.node

      tagid = undefined
      tagcount = 0

      # Use the first tagid for which there's a count
      for past_focused_tagid in @focus_tagids
        if node.tagcounts?[past_focused_tagid]
          tagid = past_focused_tagid
          tagcount = node.tagcounts[past_focused_tagid]
          break

      if tagid? && tagcount
        color = @tag_id_to_color[tagid]
        this._draw_tagcount(px.left, px.top, px.width, px.height, color, tagcount / node.doclist.n)

      ctx = @ctx
      ctx.lineWidth = this._animated_node_to_line_width(animated_node)
      ctx.strokeStyle = this._drawable_node_to_line_color(drawable_node)

      ctx.strokeRect(px.left, px.top, px.width, px.height)

      this._maybe_draw_collapse(drawable_node)
      this._maybe_draw_expand(drawable_node)
      this._maybe_draw_description(drawable_node)

      if drawable_node.parent?
        parent_px = drawable_node.parent._px
        @_draw_line_from_parent_to_child(parent_px, px)

    _draw_line_from_parent_to_child: (parent_px, child_px) ->
      x1 = parent_px.hmid
      y1 = parent_px.top + parent_px.height
      x2 = child_px.hmid
      y2 = child_px.top
      mid_y = 0.5 * (y1 + y2)

      ctx = @ctx
      ctx.lineWidth = @options.connector_line_width
      ctx.beginPath()
      ctx.moveTo(x1, y1)
      ctx.bezierCurveTo(x1, mid_y + (0.1 * child_px.height), x2, mid_y - (0.1 * child_px.height), x2, y2)
      ctx.stroke()

      undefined

  class TreeView
    observable(this)

    constructor: (@div, @cache, @tree, @focus, options={}) ->
      options_color = _.extend({}, options.color, DEFAULT_OPTIONS.color)
      @options = _.extend({}, DEFAULT_OPTIONS, options, { color: options_color })
      @focus_tagids = (t.id for t in @cache.tag_store.tags)

      $div = $(@div)
      @canvas = $("<canvas width=\"#{$div.width()}\" height=\"#{$div.height()}\"></canvas>")[0]
      $div.append(@canvas)
      @$hover_node_description = $('<div class="hover-node-description" style="display:none;"></div>')
      $div.append(@$hover_node_description) # FIXME find a better place for this

      this._attach()
      this.update()

    nodeid_above: (nodeid) ->
      @tree.id_tree.parent[nodeid]

    nodeid_below: (nodeid) ->
      try_nodeid = @tree.id_tree.children[nodeid]?[0]
      if @tree.on_demand_tree.nodes[try_nodeid]?
        try_nodeid
      else
        undefined

    # Returns the sibling (left or right) of the given node, or undefined if
    # there is no sibling.
    #
    # Parameters:
    # * nodeid: node ID to start at
    # * index_diff: +1 for node to the right; -1 for node to the left
    _nodeid_sibling: (nodeid, index_diff) ->
      parent_nodeid = @tree.id_tree.parent[nodeid]
      return undefined if !parent_nodeid?
      siblings = @tree.id_tree.children[parent_nodeid]
      node_index = siblings.indexOf(nodeid)
      sibling_index = node_index + index_diff
      if 0 <= sibling_index < siblings.length
        siblings[sibling_index]
      else
        undefined

    # Returns the node to the left or right of the given node.
    #
    # If there is no sibling, this method will traverse the tree to find a node
    # as nearby as possible and as close to the same level as possible.
    _nearby_nodeid_at_nearest_level: (nodeid, index_diff) ->
      # Make "nodeid" go up the tree until sibling_nodeid is found. Count the
      # levels we climb.
      levels_away = 0
      sibling_nodeid = undefined

      while true
        parent_nodeid = @tree.id_tree.parent[nodeid]
        return undefined if !parent_nodeid?
        sibling_nodeid = @_nodeid_sibling(nodeid, index_diff)
        if !sibling_nodeid?
          nodeid = parent_nodeid
          levels_away += 1
        else
          break

      # Descend the number of levels we've climbed. At the end, sibling_id will
      # be the result we want. parent_nodeid will be one above, in case we can't
      # descend all the way
      parent_nodeid = undefined # never return the parent
      while levels_away > 0 && sibling_nodeid?
        parent_nodeid = sibling_nodeid
        siblings = @tree.id_tree.children[parent_nodeid]
        # sibling_index: rightmost or leftmost index
        sibling_index = index_diff < 0 && (siblings.length - 1) || 0
        sibling_nodeid = siblings[sibling_index]
        # don't descend to nodes that can't be drawn
        sibling_nodeid = undefined if !@tree.id_tree.children[sibling_nodeid]
        levels_away -= 1

      sibling_nodeid || parent_nodeid

    nodeid_left: (nodeid) -> @_nearby_nodeid_at_nearest_level(nodeid, -1)

    nodeid_right: (nodeid) -> @_nearby_nodeid_at_nearest_level(nodeid, 1)

    _attach: () ->
      update = this._set_needs_update.bind(this)
      @tree.observe('needs-update', update)
      @focus.observe('needs-update', update)
      @focus.observe('zoom', update)
      @focus.observe('pan', update)
      @cache.tag_store.observe('tag-changed', update)
      $(window).on('resize.tree-view', update)

      @cache.tag_store.observe('tag-added', this._on_tag_added.bind(this))
      @cache.tag_store.observe('tag-removed', this._on_tag_removed.bind(this))
      @cache.tag_store.observe('tag-id-changed', this._on_tagid_changed.bind(this))

      $(@canvas).on 'mousedown', (e) =>
        action = this._event_to_action(e)
        @set_hover_node(undefined) # on click, un-hover
        this._notify(action.event, action.id) if action

      this._handle_hover()
      this._handle_drag()
      this._handle_mousewheel()

    _on_tag_added: (tag) ->
      @focus_tagids.unshift(tag.id)
      # No need to redraw: that will happen elsewhere if necessary.

    _on_tag_removed: (tag) ->
      index = @focus_tagids.indexOf(tag.id)
      if index != -1
        @focus_tagids.splice(index, 1)
      # No need to redraw: that will happen elsewhere if necessary.

    _on_tagid_changed: (old_tagid, tag) ->
      index = @focus_tagids.indexOf(old_tagid)
      if index != -1
        @focus_tagids[index] = tag.id
      # No need to redraw: it would produce the same result.

    _handle_hover: () ->
      $(@canvas).on 'mousemove', (e) =>
        dn = @_event_to_drawable_node(e) # might be undefined
        @set_hover_node(dn)
        e.preventDefault()

      $(@canvas).on 'mouseleave', (e) =>
        @set_hover_node(undefined)
        e.preventDefault()

    _handle_drag: () ->
      $(@canvas).on 'mousedown', (e) =>
        return if e.which != 1
        e.preventDefault()

        @focus.block_auto_pan_zoom()

        start_x = e.pageX
        dx_max = 0
        zoom = @focus.zoom
        start_pan = @focus.pan
        width = $(@canvas).width()

        update_from_event = (e) =>
          dx = e.pageX - start_x
          dx_max = dx if dx > dx_max
          return if dx_max < MIN_PAN_DISTANCE
          d_pan = (dx / width) * zoom

          this._notify('zoom-pan', { zoom: zoom, pan: start_pan - d_pan })

        $('body').append('<div id="mousemove-handler"></div>')
        $(document).on 'mousemove.tree-view', (e) ->
          update_from_event(e)
          e.stopImmediatePropagation() # prevent normal hover operation
          e.preventDefault()

        $(document).on 'mouseup.tree-view', (e) =>
          @focus.unblock_auto_pan_zoom()
          update_from_event(e)
          $('#mousemove-handler').remove()
          $(document).off('.tree-view')
          e.preventDefault()

    _handle_mousewheel: () ->
      # When the user moves mouse wheel in, we divide zoom by a factor of
      # mousewheel_zoom_factor. We adjust pan to whatever will keep the mouse
      # cursor pointing to the same location, in absolute terms.
      #
      # Before zoom, absolute location is pan1 + (cursor_fraction - 0.5) * zoom1
      # After, it's pan2 + (cursor_fraction - 0.5) * zoom2
      #
      # So pan2 = pan1 + (cursor_fraction - 0.5) * zoom1 - (cursor_fraction - 0.5) * zoom2
      $(@canvas).on 'mousewheel', (e) =>
        e.preventDefault()
        offset = $(@canvas).offset()
        x = e.pageX - offset.left
        width = $(@canvas).width()

        sign = e.deltaY > 0 && 1 || -1

        zoom1 = @focus.zoom
        zoom2 = zoom1 * Math.pow(@options.mousewheel_zoom_factor, -sign)
        pan1 = @focus.pan
        relative_cursor_fraction = ((x / width) - 0.5)

        pan2 = pan1 + relative_cursor_fraction * zoom1 - relative_cursor_fraction * zoom2

        this._notify('zoom-pan', { zoom: zoom2, pan: pan2 })

    _event_to_drawable_node: (e) ->
      offset = $(@canvas).offset()
      x = e.pageX - offset.left
      y = e.pageY - offset.top

      @last_draw?.pixel_to_drawable_node(x, y)

    _event_to_action: (e) ->
      return undefined if !@tree.root?

      offset = $(@canvas).offset()
      x = e.pageX - offset.left
      y = e.pageY - offset.top

      @last_draw?.pixel_to_action(x, y)

    _redraw: () ->
      # Add the focused tag to "focus tagids": stack of recently-viewed tags
      # (initialized to all tags)
      tagid = @tree.state.focused_tag?.id
      if tagid
        index = @focus_tagids.indexOf(tagid)
        if index == -1
          throw "Invalid tag"
        else if index != 0
          @focus_tagids.splice(index, 1)
          @focus_tagids.unshift(tagid)

      # Cache colors, so each node shows most-recently-selected tag.
      color_table = new ColorTable()
      tag_id_to_color = {}
      for tag in @cache.tag_store.tags
        id = "#{tag.id}"
        color = tag.color || color_table.get(tag.name)
        tag_id_to_color[id] = color

      shown_tagids = @tree.state.selection.tags
      shown_tagids = @focus_tagids if !shown_tagids.length

      @last_draw = new DrawOperation(@canvas, @tree, tag_id_to_color, shown_tagids, @tree.state.selection.nodes, @focus, @options)
      @last_draw.draw()

    update: () ->
      @tree.update()
      @focus.update()
      this._redraw()
      @_needs_update = @tree.needs_update() || @focus.needs_update()

    needs_update: () ->
      @_needs_update

    _set_needs_update: () ->
      if !@_needs_update
        @_needs_update = true
        this._notify('needs-update')

    # Sets the node being hovered.
    #
    # We'll adjust @$hover_node_description to match.
    set_hover_node: (drawable_node) ->
      px = drawable_node?._px
      if !px?
        @$hover_node_description.removeAttr('data-node-id')
        @$hover_node_description.hide()
        return

      # If we're here, drawable_node is valid
      node = drawable_node.animated_node.node
      node_id_string = "#{node?.id}"

      return if @$hover_node_description.attr('data-node-id') == node_id_string

      # If we're here, we're hovering on a new node
      @$hover_node_description.hide()
      @$hover_node_description.empty()

      html = HOVER_NODE_TEMPLATE({ node: node })
      @$hover_node_description.append(html)
      @$hover_node_description.attr('data-node-id', node_id_string)
      @$hover_node_description.css({ opacity: 0.001 })
      @$hover_node_description.show() # Show it, so we can calculate dims

      h = @$hover_node_description.outerHeight(true)
      w = @$hover_node_description.outerWidth(true)

      $canvas = $(@canvas)
      offset = $canvas.offset()
      document_width = $(document).width()

      top = px.top - h
      left = px.hmid - w * 0.5

      if left + offset.left < 0
        left = 0
      if left + offset.left + w > document_width
        left = document_width - w - offset.left

      @$hover_node_description.css({
        left: left
        top: top
      })
      @$hover_node_description.animate({ opacity: 0.9 }, 'fast')

# wrapping class to hold an flickr photo
class Flickr::Photos::Photo
  attr_accessor :id, :owner, :secret, :server, :farm, :title, :is_public, :is_friend, :is_family # standard attributes
  attr_accessor :license_id, :uploaded_at, :taken_at, :owner_name, :icon_server, :original_format, :updated_at, :geo, :tags, :machine_tags, :o_dims, :views, :media # extra attributes
  attr_accessor :info_added, :description, :original_secret, :owner_username, :owner_realname, :url_photopage, :notes # info attributes
  attr_accessor :comments # comment attributes
  
  # create a new instance of a flickr photo.
  # 
  # Params
  # * flickr (Required)
  #     the flickr object
  # * attributes (Required)
  #     a hash of attributes used to set the initial values of the photo object
  def initialize(flickr, attributes)
    @flickr = flickr
    attributes.each do |k,v|
      send("#{k}=", v)
    end
  end

  # Alias to image_url method
  def url(size = :medium)
    image_url(size)
  end

  # retreive the url to the image stored on flickr
  #
  # == Params
  # * size (Optional)
  #     the size of the image to return. Optional sizes are:
  #       :square - square 75x75
  #       :thumbnail - 100 on longest side
  #       :small - 240 on longest side
  #       :medium - 500 on longest side
  #       :large - 1024 on longest side (only exists for very large original images)
  #       :original - original image, either a jpg, gif or png, depending on source format
  #
  def image_url(size = :medium)
	# It turns out that flickr always stores all the sizes of the picture even when getSizes call returns otherwise.
	# Not calling getSizes is also very important for performance reasons.
	# Retrieving 30 search results means calling the API 31 times if you call getSizes every time.
	# Mind that you still need to call getSizes if you go out for the original image.
	if size == :original
	  size_hash[size.to_s].source if size_hash.has_key? size.to_s
	else
	  key = "_#{size_key(size.to_sym)}"
	  key = "" if key == "_"
	  "http://farm#{farm}.static.flickr.com/#{server}/#{id}_#{secret}#{key}.jpg"
	end
  end

  def photopage_url
	# Keeping the same convention as image_url (foo_url)
	url_photopage
  end

  def video_url
    if size_hash['video player']
      size_hash['video player'].source
    end
  end

  # save the current photo to the local computer
  # 
  # == Params
  # * filename (Required)
  #     name of the new file omiting the extention (ex. photo_1)
  # * size (Optional)
  #     the size of the image to return. Optional sizes are:
  #       :small - square 75x75
  #       :thumbnail - 100 on longest side
  #       :small - 240 on longest side
  #       :medium - 500 on longest side
  #       :large - 1024 on longest side (only exists for very large original images)
  #       :original - original image, either a jpg, gif or png, depending on source format
  # 
  def save_as(filename, size = :medium)
    format = size.to_sym == :original ? self.original_format : 'jpg'
    filename = "#{filename}.#{format}"

    if File.exists?(filename) or not self.url(size)
      false
    else
      f = File.new(filename, 'w+')
      f.puts open(self.url(size)).read
      f.close
      f
    end
  end
  
  # Add tags to a photo.
  # 
  # Params
  # * tags (Required)
  #     comma seperated list of tags
  # 
  def add_tags(tags)
    @flickr.send_request('flickr.photos.addTags', {:photo_id => self.id, :tags => tags}, :post)
    true
  end
  
  # Add comment to a photo as the currently authenticated user.
  #
  # Params
  # * message (Required)
  #     text of the comment
  #
  def add_comment(message)
    @flickr.send_request('flickr.photos.comments.addComment', {:photo_id => self.id, :comment_text => message}, :post)
    true
  end
  
  # Add a note to a photo. Coordinates and sizes are in pixels, based on the 500px image size shown on individual photo pages.
  # 
  # Params
  # * message (Required)
  #     The text of the note
  # * x (Required)
  #     The left coordinate of the note
  # * y (Required)
  #     The top coordinate of the note
  # * w (Required)
  #     The width of the note
  # * h (Required)
  #     The height of the note
  #     
  def add_note(message, x, y, w, h)
    @flickr.send_request('flickr.photos.notes.add', {:photo_id => self.id, :note_x => x, :note_y => y, :note_w => w, :note_h => h, :note_text => message}, :post)
    true
  end
  
  # Rotate a photo.
  # 
  # Params
  # * degrees (Required)
  #     The amount of degrees by which to rotate the photo (clockwise) from it's current orientation. Valid values are 90, 180 and 270.
  # 
  def rotate(degrees)
    @flickr.send_request('flickr.photos.transform.rotate', {:photo_id => self.id, :degrees => degrees}, :post)
    true
  end
  
  # return the license associated with the photo
  # 
  def license
    @flickr.photos.licenses[self.license_id]
  end
  
  # Sets the license for a photo.
  # 
  # Params
  # * license_id (Required)
  #     The license to apply, or 0 (zero) to remove the current license.
  def set_license(license_id)
    @flickr.send_request('flickr.photos.licenses.setLicense', {:photo_id => self.id, :license_id => license_id}, :post)
    true
  end
  
  def description # :nodoc:
    attach_info
    @description
  end

  def original_secret # :nodoc:
    attach_info
    @original_secret
  end

  def owner_username # :nodoc:
    attach_info
    @owner_username
  end

  def owner_realname # :nodoc:
    attach_info
    @owner_realname
  end

  def url_photopage # :nodoc:
    attach_info
    @url_photopage
  end

  def comments # :nodoc:
    @comments ||= begin
      if @comment_count == 0
        self.comments = []
        self.comments_added = true
      elsif not self.comments_added
        rsp = @flickr.send_request('flickr.photos.comments.getList', :photo_id => self.id)
        
        self.comments = []
        self.comments_added = true
        
        rsp.comments.comment.each do |comment|
          self.comments << Flickr::Photos::Comment.new(:id => comment[:id],
            :comment => comment.to_s,
            :author => comment[:author],
            :author_name => comment[:authorname],
            :permalink => comment[:permalink],
            :created_at => (Time.at(comment[:datecreate].to_i) rescue nil))
        end
      end        
    end
  end
  
  def sizes # :nodoc:
    @sizes ||= begin
      rsp = @flickr.send_request('flickr.photos.getSizes', :photo_id => self.id)
      
      _sizes = []
      rsp.sizes.size.each do |size|
        _sizes << Flickr::Photos::Size.new(:label => size[:label], :width => size[:width],
          :height => size[:height], :source => size[:source], :url => size[:url])
      end
      _sizes
    end
  end

  def notes # :nodoc:
    attach_info
    @notes
  end

  protected
  def size_hash
    @size_hash ||= begin
      hash = {}
      sizes.each do |size|
        hash[size.label.downcase] = size
      end
      hash
    end
  end

  private
  attr_accessor :comment_count
  
  # convert the size to the key used in the flickr url
  def size_key(size)
    case size.to_sym
    when :square then 's'
    when :thumb, :thumbnail then 't'
    when :small then 'm'
    when :medium then ''
    when :large then 'b'
    when :original then 'o'
    else ''
    end
  end

  # loads photo info when a field is requested that requires additional info
  def attach_info
    unless self.info_added
      rsp = @flickr.send_request('flickr.photos.getInfo', :photo_id => self.id, :secret => self.secret)

      self.info_added = true
      self.description = rsp.photo.description.to_s.strip
      self.original_secret = rsp.photo[:originalsecret]
      self.owner_username = rsp.photo.owner[:username]
      self.owner_realname = rsp.photo.owner[:realname]
      self.url_photopage = rsp.photo.urls.url.to_s
      self.comment_count = rsp.photo.comments.to_s.to_i

      self.notes = []

      rsp.photo.notes.note.each do |note|
        self.notes << Flickr::Photos::Note.new(:id => note[:id],
		  :note => note.to_s,
		  :author => note[:author],
		  :author_name => note[:authorname],
		  :x => note[:x],
		  :y => note[:y],
		  :width => note[:w],
		  :height => note[:h])
      end if rsp.photo.notes.note
    end
  end
end

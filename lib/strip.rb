module Strip

  # SCB outputs some weird whitespace characters

  def self.mystrip(str)
    return str unless str and str.length > 0
    str = str.strip
    while str and str.length > 0 and str[0].ord == 160
      str = str.slice(1,1000)
    end
    while str and str.length > 0 and str[str.length-1].ord == 160 do
      str = str.slice(0,str.length-1)
    end
    return str.strip
  end

end

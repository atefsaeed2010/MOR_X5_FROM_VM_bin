  ############ MATRIX CLASS ##############

  class Matrix < Array
    def initialize (rows, columns)
      super(rows)
      self.each_index { |i|
        self[i] = Array.new(columns)
        self[i].each_index { |j| self[i][j] = rand(10) }
      }
    end

    def sort(key, order)
      key = key.to_i
      order = order.to_s

      b = Matrix.new(self.size, self[0].size)

      s_row = self[key].sort

      s_row = s_row.reverse if order == "desc"

      i=0
      zz = 0
      while i<self[0].size
        j=0
        while self[key][j] != s_row[i]
          j += 1
        end

        for zz in 0..self.size-1
          b[zz][i] = self[zz][j]
        end
        self[key][j] = "s" #mark as used

        i+=1

      end

      b
    end

    #put value into file for debugging
    def my_debug(msg)
      File.open(Debug_File, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end
  end
  ############ MATRIX CLASS ##############

  class Matrix < Array
    def initialize (rows, columns)
      super(rows)
      self.each_index { |i|
        self[i] = Array.new(columns)
        self[i].each_index { |j| self[i][j] = rand(10) }
      }
    end

    def sort(key, order)
      key = key.to_i
      order = order.to_s

      b = Matrix.new(self.size, self[0].size)

      s_row = self[key].sort

      s_row = s_row.reverse if order == "desc"

      i=0
      zz = 0
      while i<self[0].size
        j=0
        while self[key][j] != s_row[i]
          j += 1
        end

        for zz in 0..self.size-1
          b[zz][i] = self[zz][j]
        end
        self[key][j] = "s" #mark as used

        i+=1

      end

      b
    end

    #put value into file for debugging
    def my_debug(msg)
      File.open(Debug_File, "a") { |f|
        f << msg.to_s
        f << "\n"
      }
    end
  end
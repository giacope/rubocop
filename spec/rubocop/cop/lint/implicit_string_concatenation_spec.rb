# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Lint::ImplicitStringConcatenation, :config do
  context 'on a single string literal' do
    it 'does not register an offense' do
      expect_no_offenses('abc')
    end
  end

  context 'on adjacent string literals on the same line' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class A; "abc" "def"; end
                 ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation.
        class B; 'ghi' 'jkl'; end
                 ^^^^^^^^^^^ Combine 'ghi' and 'jkl' into a single string literal, rather than using implicit string concatenation.
      RUBY

      expect_correction(<<~RUBY)
        class A; "abc" + "def"; end
        class B; 'ghi' + 'jkl'; end
      RUBY
    end
  end

  context 'on adjacent string interpolation literals on the same line' do
    it 'registers an offense' do
      expect_offense(<<~'RUBY')
        "string#{interpolation}" "def"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine "string#{interpolation}" and "def" into a single string literal, rather than using implicit string concatenation.
      RUBY

      expect_correction(<<~'RUBY')
        "string#{interpolation}" + "def"
      RUBY
    end
  end

  context 'on adjacent string interpolation literals on the same line with multiple concatenations' do
    it 'registers an offense' do
      expect_offense(<<~'RUBY')
        "foo""string#{interpolation}""bar"
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine "string#{interpolation}" and "bar" into a single string literal, rather than using implicit string concatenation.
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine "foo" and "string#{interpolation}" into a single string literal, rather than using implicit string concatenation.
      RUBY

      expect_correction(<<~'RUBY')
        "foo" + "string#{interpolation}" + "bar"
      RUBY
    end
  end

  context 'on adjacent string literals with triple quotes' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        """string"""
          ^^^^^^^^^^ Combine "string" and "" into a single string literal, rather than using implicit string concatenation.
        ^^^^^^^^^^ Combine "" and "string" into a single string literal, rather than using implicit string concatenation.
      RUBY

      expect_correction(<<~RUBY)
        "string"
      RUBY
    end
  end

  context 'on adjacent string literals on different lines' do
    it 'does not register an offense' do
      expect_no_offenses(<<~'RUBY')
        array = [
          'abc'\
          'def'
        ]
      RUBY
    end
  end

  context 'when implicitly concatenating a string literal with a line break and string interpolation' do
    it 'registers an offense' do
      expect_offense(<<~'RUBY')
        'single-quoted string'"string
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Combine 'single-quoted string' and "string\n" into a single string literal, rather than using implicit string concatenation.
        #{interpolation}"
      RUBY

      expect_correction(<<~'RUBY')
        'single-quoted string' + "string
        #{interpolation}"
      RUBY
    end
  end

  context 'when the string literals contain newlines' do
    it 'registers an offense' do
      expect_offense(<<~'RUBY')
        def method
          "ab
          ^^^ Combine "ab\nc" and "de\nf" into a single string literal, [...]
        c" "de
        f"
        end
      RUBY

      expect_correction(<<~RUBY)
        def method
          "ab
        c" + "de
        f"
        end
      RUBY
    end

    it 'does not register an offense for a single string' do
      expect_no_offenses(<<~RUBY)
        'abc
        def'
      RUBY
    end
  end

  context 'on a string with interpolations' do
    it 'does register an offense' do
      expect_no_offenses("array = [\"abc\#{something}def\#{something_else}\"]")
    end
  end

  context 'when inside an array' do
    it 'notes that the strings could be separated by a comma instead' do
      expect_offense(<<~RUBY)
        array = ["abc" "def"]
                 ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate array elements, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        array = ["abc" + "def"]
      RUBY
    end
  end

  context 'when the string literals are the receiver of a method call' do
    it 'registers an offense and corrects with parentheses' do
      expect_offense(<<~RUBY)
        "abc" "def".upcase
        ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        ("abc" + "def").upcase
      RUBY
    end

    it 'registers an offense and corrects with parentheses when there are multiple concatenations' do
      expect_offense(<<~RUBY)
        "abc" "def" "ghi".upcase
              ^^^^^^^^^^^ Combine "def" and "ghi" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
        ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        ("abc" + "def" + "ghi").upcase
      RUBY
    end
  end

  context 'when the string literals are the receiver of an operator' do
    it 'registers an offense and corrects with parentheses' do
      expect_offense(<<~RUBY)
        "%s and " "%s" % [a, b]
        ^^^^^^^^^^^^^^ Combine "%s and " and "%s" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        ("%s and " + "%s") % [a, b]
      RUBY
    end
  end

  context 'when the string literals are the operand of `+`' do
    it 'registers an offense and corrects with parentheses' do
      expect_offense(<<~RUBY)
        base + "abc" "def"
               ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        base + ("abc" + "def")
      RUBY
    end
  end

  context 'when the string literals are the operand of an operator with lower precedence than `+`' do
    it 'registers an offense and corrects without parentheses' do
      expect_offense(<<~RUBY)
        value == "abc" "def"
                 ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        value == "abc" + "def"
      RUBY
    end
  end

  context "when in a method call's argument list" do
    it 'notes that the strings could be separated by a comma instead' do
      expect_offense(<<~RUBY)
        method("abc" "def")
               ^^^^^^^^^^^ Combine "abc" and "def" into a single string literal, rather than using implicit string concatenation. Or, if they were intended to be separate method arguments, separate them with a comma.
      RUBY

      expect_correction(<<~RUBY)
        method("abc" + "def")
      RUBY
    end
  end
end

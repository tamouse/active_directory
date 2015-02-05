# Notes on Problems Changing Passwords

    Time-stamp: <2015-02-03 21:15:48 tamara>

The proper sequence and data to change a user's password in
ActiveDirectory remains ellusive. The code used, both in the original
and from investigation always returns the same error message: "Will
not execute".

## Error message

The message set returned from `Net::LDAP#modify` looks as follows:

    #<OpenStruct code=53, error_message="0000052D: SvcErr: DSID-031A120C, problem 5003 (WILL_NOT_PERFORM), data 0\n\x00", matched_dn="", message="Unwilling to perform">


## Original code

The original author's code took the password and attempted to convert
it to a UTF-16LE wide byte code by performing the following:

    def self.encode(password)
      ("\"#{password}\"".split(//).collect { |c| "#{c}\000" }).join
    end

## Investigating sources of error

Almost everything that I have been able to find points to one of two
issues:

a) Improperly encoded password

b) Lack of permissions to change password

Thinking that the most likely cause was a), pursuit of several avenues
led to a stackoverflow question that seems the most useful:

<http://stackoverflow.com/questions/16367690/how-to-reset-ldap-user-password-without-old-password-using-the-netldap-gem-or#comment23513903_16367714>

> `Ldap.modify(:dn => "uid=test_1,ou=people,dc=sde,dc=myserver,dc=com",
  :operations =>
  [:replace, :unicodePwd, Iconv.conv('UTF-16LE', 'UTF-8', '"'+"hello"+'"')])`
  Your suggestion should work. The user I was using didn't have the
  right privileges. -- I had to make a request to the infrastructure
  team..... (corporate --)..... Thanks! –  Richardsondx May 6 '13 at
  15:59 

However, even after implementing this in
`active_directory/lib/active_directory/field_type/password.rb`, the
same error as above is produced.

      def self.encode(password)
        # ("\"#{password}\"".split(//).collect { |c| "#{c}\000" }).join
        quoted_password = ?" + password + ?"
        converted_password = Iconv.iconv('UTF-16LE', 'UTF-8', quoted_password)
        binding.pry
        converted_password
      end

An email from AD Admin informs that we do have
permissions with our credentials to change passwords.

\[email redacted\]

*******

## Investigations

* <http://stackoverflow.com/questions/21316740/modifying-active-directory-passwords-via-ldapmodify>
  discusses a similar problem, but written in Python and setting the
  password on account creation instead of modification. The methods
  described here made no difference when converted to ruby code and
  libraries.

* <http://stackoverflow.com/a/6802169/742446> is again, a similar
  problem, but in Java. The solution tried and working for them is to
  convert to UTF-16LE, and then Base64 encoding. This is did not work
  for us either.


* <http://stackoverflow.com/a/25129533/742446> in the same question
  goes through a deeper explanation of things that can go wrong. This
  points to <http://support.microsoft.com/kb/269190>.

    * 128-bit secure connection: check

    * Binding as an adminimstrator: maybe?

    * Syntax of `unicodePwd`: UNICODE string that are BER (Basic Encoding
      Rules) as an octet string. The BER encoding is done deep inside the
      Net::LDAP::Connection#modify method, so we should not double dip on
      that. check.

* In this followup 
  [How to reset ldap user password without `old_password`? Using the `Net::Ldap` gem or `devise_ldap_authenticatable` gem][stackoverflow]
  the "definitive" statement is: It turns out that it has to be UTF-16LE
  encoded, and then converted to base64.

* <http://www.ramblingtech.com/will_not_perform-error-from-ad-on-password-change-using-java/>
  also deals with Java, and only discusses the need for UTF-16LE
  encoding, **not** Base64 encoding as well.

* later, though, there is discussion about it. Again, though, this
  should be handled via the Net::LDAP library for us.

* In [Changing password in ActiveDirectory using Ruby and Net/LDAP][bronislavrobenek]
  turns out to be the same result as the original password encoding in
  AD::FieldTypes::Password. We should use this, as it is much clearer.
  
## Testing directly with Net::LDAP

Rather than continue to hack on AD::User, I decided to test with LDAP
itself.

I demonstrate 4 encoding methods, based upon the learning from above,
including the original. Briefly, these are:

### Encodings

#### encoding 1 - original

    ("\"#{password}\"".split(//).collect { |c| "#{c}\000" }).join

#### encoding 2 - from [bronislavrobenek]

    ('"' + password + '"').encode("utf-16le").force_encoding("utf-8")

#### encoding 3 - from [stackoverflow]

    Iconv.conv('UTF-16LE', 'UTF-8', (?" + password + ?"))

#### encoding 4 - encoding 3 forced to UTF8

    Iconv.conv('UTF-16LE', 'UTF-8', (?" + password + ?")).force_encoding('UTF-8')

### Results: SUCCESS! (partially)

Encodings 1, 2, and 4 all work, all return the same value. Encoding 3
does *NOT* work, which is interesting considering all the people that
say it does on SO.

The test in `./livewire-testing/ldap_direct_spec.rb` is intentionally
contrived, but it shows that you *can* change the password, and that
therefore, the credientials are *NOT* the issue. The issue lies in the
implementation in `ActiveDirectory::User`.

[bronislavrobenek]: http://blog.bronislavrobenek.com/post/80163028550/changing-password-in-activedirectory-using-ruby

[stackoverflow]: http://stackoverflow.com/questions/6797955/how-do-i-resolve-will-not-perform-ms-ad-reply-when-trying-to-change-password-i#comment8070187_6798151


## What is wrong in `AD::User` then?

Here is the code for the `change_password` method:

``` ruby
def change_password(new_password, force_change = false)
  settings = @@settings.dup.merge({
      :port => 636,
      :encryption => { :method => :simple_tls }
    })

  ldap = Net::LDAP.new(settings)
  operations = [
    [ :replace, :lockoutTime, [ '0' ] ],
    [ :replace, :unicodePwd, [ FieldType::Password.encode(new_password) ] ],
    [ :replace, :userAccountControl, [ UAC_NORMAL_ACCOUNT.to_s ] ],
    [ :replace, :pwdLastSet, [ (force_change ? '0' : '-1') ] ]
  ]
  ldap.modify(:dn => distinguishedName, :operations => operations)
end
```

The code is creating it's own ldap adapter, presumably not to
interfere with the global one in the class (why, oh, why use
singletons when you really need instances??).

It turns out, this local adapter **never gets bound**, which is what
is causing all the problems. Adding a single line below the new ldap
adapter fixes all the problems:

``` ruby
  ldap = Net::LDAP.new(settings)
  ldap.bind # <-- this is the fix
```



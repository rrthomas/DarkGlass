# Security

First, a disclaimer: serious security is beyond the scope of this manual. Secondly, Linton's main goal is to make publishing easy; security is not its primary goal.

=_Hiding content_=
    Linton's basic security mechanism is to use file permissions. It is expected that Linton will run as a different user from the content's owner, so that making a file non-world-readable will hide it from Linton. If you use Linton to export your home directory, you should set a umask that makes files non-world-readable by default.
=_Password-protection_=
    It may be preferable to require a password for some content. To do this, place the content in a directory that is itself protected by HTTP authentication. The details of how to do this depend on the web server; instructions for Apache can be found [in its manual](https://httpd.apache.org/docs/howto/auth.html#basic).
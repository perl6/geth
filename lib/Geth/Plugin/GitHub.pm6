use IRC::Client;
unit class Geth::Plugin::GitHub is IRC::Client::Plugin;

use IRC::TextColor;
use Geth::Config;
use Geth::GitHub::Hooks;
has $.host is required;
has $.port is required;

constant &Δ = &irc-style-text;

method irc-started {
    start react {
        whenever Geth::GitHub::Hooks.new(:$!host, :$!port, :9debug) -> $e {
            my @chans = $e.query<chan>.?split: ',';
            my @bot-chans = |conf<channels>;
            # XXX TODO: https://github.com/zoffixznet/perl6-IRC-Client/issues/37
            # $.irc.servers».channels.flat.map({
                # $_ ~~ Pair ?? .key !! $_
            # });

            dd [ 'chans', @chans, @bot-chans, @chans ⊆ @bot-chans ];

            if @chans ⊆ @bot-chans {
                my $text = make-text $e;
                for @chans -> $where {
                    $.irc.send: :$where, :text($_) for $text.lines;
                }
            }

            CATCH { default { .gist.say } }
        }
    }
}

sub make-text ($e) {
    when $e ~~ Geth::GitHub::Hooks::Event::Push {
        if $e.commits.elems > 3 {
            my @branches = $e.commits».branch.unique.sort;
            prefix-lines $e.repo ~ (
                    @branches == 1 ?? "/@branches[0]"
                    !! @branches > 4 ?? "/\{" ~ +@branches ~ ' branches}'
                    !! '{' ~ @branches.join(',') ~ '}'
                ),
                Δ(:style<bold>, "$e.commits.elems() commits ")
                ~ "pushed by &karma-name($e.pusher)",
                (
                    $e.commits.map: *.&make-short-commit-message: $e
                        if $e.commits.elems < 10
                ),
                Δ :style<bold>,
                    "review: https://github.com/$e.repo-full()/compare/"
                    ~ $e.commits[ 0 ].sha.substr(0,10) ~ '…'
                    ~ $e.commits[*-1].sha.substr(0,10);
        }
        else {
            join "\n", flat $e.commits.map: *.&make-full-commit-message: $e;
        }
    }
}

sub make-short-commit-message ($c, $e) {
    "$c.sha.substr(0, 10) | &Δ(:style<bold>, $c.title)…"
}

sub make-full-commit-message ($c, $e) {
    my $header = $c.sha.substr(0, 10) ~ ' | '
        ~ karma-name($c.author) ~ ' | '
        ~ ($c.files == 1 ?? |$c.files !! "$c.files.elems() files");

    my $message = Δ(:style<bold>, $c.title);
    if $c.message.lines.elems -> $n {
        $message ~= "\n\n" ~ ($n < 10 ?? $c.message !! (
            join "\n", flat $c.message.lines[^10],
                Δ :style<italic>, "<…commit message has {$n - 10} more lines…>";
        ));
    }

    my $review = Δ :style<bold>,
        "review: https://github.com/$e.repo-full()/commit/$c.sha.substr(0, 10)";

    prefix-lines $e.repo ~ ("/$c.branch()" unless $c.branch eq 'master'|'nom'),
        $header, $message, $review;
}

sub karma-name {
    ($^author ~~ /\s/ ?? "($author)" !! $author) ~ '++'
}

sub prefix-lines ($pref, *@text) {
    join "\n", map {"$pref: $_"}, @text.join("\n").lines;
}
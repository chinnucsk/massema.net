%% -*- mode: erlang; erlang-indent-level: 2 -*-
%%% Created : 27 Jun 2012 by mats cronqvist <masse@klarna.com>

%% @doc
%% the massema.net server
%% @end

-module(mm).
-author('mats cronqvist').
-export([start/0,
         do/2,
         logg/1]).

start() ->
  [egeoip:start() || not is_started(egeoip)],
  [inets:start() || not is_started(inets)],
  inets:start(httpd,conf()).

%% we rely on the convention that the error log lives in ".../<app>/<logfile>"
%% and static pages lives in priv_dir/static
conf() ->
  {ok,{file,ErrorLog}} = application:get_env(kernel,error_logger),
  LogDir = filename:dirname(ErrorLog),
  Root = code:lib_dir(filename:basename(LogDir)),
  [{port, 8080},
   {server_name,atom_to_list(?MODULE)},
   {server_root,LogDir},
   {document_root,filename:join([Root,priv,static])},
   {modules, [mod_alias,mod_fun,mod_get,mod_log]},
   {directory_index, ["index.html"]},
   {error_log,filename:join([LogDir,"errors.log"])},
   {handler_function,{?MODULE,do}},
   {mime_types,[{"html","text/html"},
                {"css","text/css"},
                {"ico","image/x-icon"},
                {"js","application/javascript"}]}].

is_started(A) ->
  lists:member(A,[X || {X,_,_} <- application:which_applications()]).

logg(E) -> error_logger:error_report(E).

%% called from mod_fun. runs in a fresh process.
%% Req is a dict with the request data from inets. It is implemented
%% as a fun/1, with the arg being the key in the dict.
%% we can deliver the content in chunks by calling Act(Chunk).
%% the first chunk can be headers; [{Key,Val}]
%% if we don't want to handle the request, we do Act(defer)
%% if we crash, there will be a 404.
do(Act,Req) ->
  {Name,_} = proplists:get_value(real_name,Req(data)),
  case {is_tick(Req),mustasch:is_file(Name)} of
    {no,no} -> Act(defer);
    {yes,no}-> Act(ticker());
    {no,MF} -> Act(mustasch:file(MF,Req(all)))
  end.

is_tick(Req) ->
  try
    "/tick" = Req(request_uri),
    "GET" = Req(method),
    yes
  catch
    _:_ -> no
  end.

ticker() ->
  T = round(1000-element(3,now())/1000),
  receive
  after T ->
      {{Y,Mo,D},{H,Mi,S}} = calendar:now_to_local_time(now()),
      io_lib:fwrite("~w-~.2.0w-~.2.0w ~.2.0w:~.2.0w:~.2.0w",[Y,Mo,D,H,Mi,S])
  end.

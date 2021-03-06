require "sinatra"
require "slim"
require "bcrypt"
require "SQLite3"

require_relative "model.rb"

enable :sessions

db = SQLite3::Database.new('database/database.db')
db.results_as_hash = true


before do
    path = request.path_info
    whitelist = ['/', '/login', '/sign_up', '/users/update', '/users/complete_profile', '/error']
    redirect = true

    whitelist.each do |e|
        if path == e
            redirect = false
        end
    end

    if session[:id].nil? and redirect
        redirect('/')
    end

end


get('/') do
    session[:id] = nil
    # p @failed
    slim(:start)
end


post('/sign_up') do
    username = params["username"]
    password = params["password"]
    confirm_password = params["c_password"]

    result = signup(username, password, confirm_password)
    # id = id_from_username(username).first["id"]
    # p result

    if result[:error] == false
        session[:to_complete] = result[:current_user]
        redirect("users/update")
    else
        session[:error] = result[:error]
        redirect('/error')
    end
end

get('/users/update') do 
    slim(:"users/update")
end

post('/users/update') do 
    firstname = params["new_name"].downcase
    class_name = params["class"].downcase

    name_taken = name_taken(firstname, class_name)
    # session[:to_complete] = params["id"]

    if firstname.nil? == false && class_name.nil? == false && name_taken == false
        update_profile(firstname, class_name, session[:to_complete])
        session[:id] = session[:to_complete]

        redirect('/users/home')
    else
        redirect('/users/update')
    end

end

post("/login") do
    username = params["username"]
    password = params["password"]


    if session[:attempt].nil?
        session[:attempt] = Time.now
    elsif Time.now - session[:attempt] < 20 
        session[:error] = "Cannot log in at this moment. Wait a minute and try again"
        redirect('/error')
    end 
    # p Time.now - session[:attempt]
    session[:attempt] = Time.now


    result = login_snake(username, password)
    
    if result[:error] == false
        session[:id] = result[:current_user]
        
        if result[:admin] == true
            redirect('/admin/home/name')
        else
            redirect('/users/home')
        end
    elsif result[:error] == "Not completed profile"
        tester = completed_profile(username)
        
        if tester[:completed] == false && result[:admin] == false
            session[:to_complete] = tester[:id]
            redirect('/users/update')
        end
    else
        session[:error] = result[:error]
        redirect('/error') 
    end
end

post('/users/logout') do
    session[:id] = nil
    
    redirect('/')
end

get('/users/home') do
    if session[:id] == nil
        session[:error] = "Not logged in"
        
        redirect('/error')
    else
        classmates = fetch_classmates(session[:id])

        slim(:"users/home", locals:{classmates: classmates})
    end
end

get('/admin/home/:order') do
    order = params['order']
    votes = fetch_options(order)

    slim(:"../admin/home", locals:{options: votes})
end

post('/admin/order_by') do
    order = params['order']

    redirect("/admin/home/#{order}")
end

post('/admin/delete/:id') do
    option_id = params['id']
    remove_option(option_id)

    redirect('/admin/home/option_id')
end

get('/users/voting/:id') do
    id = params["id"]
    current_user = session[:id]
    result = fetch_voting_page(current_user, id)
    p result
    
    errormsg = result[:error]
    options = result[:options]
    users_vote = result[:users_vote]
    
    if errormsg != false
        session[:error] = errormsg

        redirect('/error')
    else
        slim(:"users/voting", locals:{votes: options, vote_for: id, users_vote: users_vote})
    end

end

post('/vote/new/:option_for') do
    content = params['new_option']
    option_for = params['option_for']
    
    errormsg = new_option(content, option_for)

    if errormsg != false
        session[:error] = errormsg
        redirect('/error')
    else
        redirect("/users/voting/#{option_for}")
    end
end

post('/vote/update/:vote_for/:option_id') do
    current_user = session[:id]
    option_id = params['option_id']
    vote_for = params['vote_for']

    vote(current_user, vote_for, option_id)

    redirect("/users/voting/#{vote_for}")
end

get('/error') do
    slim(:error, locals:{error_message: session[:error]})
end
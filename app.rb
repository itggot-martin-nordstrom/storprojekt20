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
    whitelist = ['/', '/login', '/sign_up', '/users/first_login', '/users/complete_profile', '/error']
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

    result = signup_passwords(username, password, confirm_password)

    # p result['error']

    if result['error'] == nil
        # session[:id] = result[:current_user]
        redirect('users/first_login')
    else
        session[:error] = result['error']
        redirect('/error')
    end
end

get('/users/first_login') do 
    slim(:"users/first_login")
end

post('/users/complete_profile') do 
    firstname = params["new_name"].downcase
    class_name = params["class"].downcase

    name_taken = name_taken(firstname, class_name)

    if firstname.nil? == false && class_name.nil? == false && name_taken == false
        finish_profile(firstname, class_name, session[:to_complete])
        session[:id] = session[:to_complete]

        redirect('/users/home')
    else
        redirect('/users/first_login')
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
    p Time.now - session[:attempt]
    session[:attempt] = Time.now


    result = login_snake(username, password)
    
    if result[:error].nil?
        session[:id] = result[:current_user]
        
        if result[:admin] == true
            redirect('/admin/home/name')
        else
            redirect('/users/home')
        end
    elsif result[:error] == "Not completed profile"
        tester = completed_profile(username)
        
        if tester[0] == false && result[:admin] == false
            session[:to_complete] = tester[1]
            redirect('/users/first_login')
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

post('/admin/remove_option/:id') do
    option_id = params['id']
    remove_option(option_id)

    redirect('/users/home')
end

get('/users/voting/:id') do
    id = params["id"]
    current_user = session[:id]
    result = fetch_voting_page(current_user, id)
    
    errormsg = result[:errormsg]
    options = result[:options]
    users_vote = result[:users_vote]
    
    if errormsg != nil
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

    if errormsg != nil
        session[:error] = errormsg
        redirect('/error')
    else
        redirect("/vote/new/#{option_for}")
    end
end

post('/vote/:vote_for/:option_id') do
    current_user = session[:id]
    option_id = params['option_id']
    vote_for = params['vote_for']

    vote(current_user, vote_for, option_id)

    redirect("/users/voting/#{vote_for}")
end

get('/error') do
    slim(:error, locals:{error_message: session[:error]})
end
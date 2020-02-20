require "sinatra"
require "slim"
require "bcrypt"
require "SQLite3"

require_relative "model.rb"

enable :sessions

db = SQLite3::Database.new('database/database.db')
db.results_as_hash = true

get('/') do
    @failed ||= false
    p @failed
    slim(:start)
end

post('/sign_up') do
    username = params["username"]
    password = params["password"]
    confirm_password = params["c_password"]

    result = signup_passwords(username, password, confirm_password)

    p result['current_user']

    if result['error'] == nil
        session[:id] = result['current_user']
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

    # p session[:id]

    db.execute("UPDATE users SET name=?, class_name=? WHERE id=?", [firstname, class_name, session[:id]])
    # ???
    redirect('/users/home')
end

post("/login") do
    username = params["username"]
    password = params["password"]

    result = db.execute("SELECT id, password_digest, class_name FROM users WHERE username = ?", username)
    if result.empty?    
        session[:error] = "Invalid credentials"
        @failed = true
        redirect('/')
    else
        user_id = result.first["id"]
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            session[:id] = user_id
            # p session[:id]
            
            redirect("/users/home")
            # if result.first["class_name"] != nil
            #     redirect("/users/home")
            # else
            #     redirect('/admin/home/id')
            # end
        else
            @failed = true
            redirect('/')
        end
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
        # p session[:id]
        # current_user = session[:id]
        
        classmates = fetch_classmates(session[:id])
        # current_class = db.execute('SELECT class_name FROM users WHERE id=?', current_user)
        # # p current_class
        
        # classmates = db.execute('SELECT id, name FROM users WHERE class_name=? AND id !=?', [current_class[0]['class_name'], current_user])
        slim(:"users/home", locals:{classmates: classmates})
    end
end

get('/admin/home/:order') do
    order = params['order']

    # p order

    votes = db.execute('SELECT option_id, name, class_name, content, no_of_votes FROM users LEFT JOIN options ON users.id = options.for_user WHERE option_id IS NOT NULL ORDER BY ?', order)
    slim(:"admin/home", locals:{options: votes})
end

post('/admin/order_by') do
    order = params['order']

    # p order

    redirect("/admin/home/#{order}")
end

post('/admin/remove_option/:id') do
    option_id = params['id']

    db.execute('DELETE FROM options WHERE option_id=?', option_id)
    db.execute('DELETE FROM votes WHERE option_id=?', option_id)

    redirect('/users/home')
end

get('/users/voting/:id') do
    id = params["id"]
    current_user = session[:id]

    # safety för användare som inte är i samma klass
    user_classname = db.execute('SELECT class_name FROM users WHERE id=?', current_user)
    target_classname = db.execute('SELECT class_name FROM users WHERE id=?', id)
    # p user_classname
    # p target_classname
    if user_classname != target_classname
        session[:error] = "Oops, you can't vote for that user!"
        redirect('/error')
    else
        options = db.execute('SELECT option_id, content, no_of_votes FROM options WHERE for_user = ? ORDER BY no_of_votes DESC', id)
        users_vote = db.execute("SELECT content FROM options WHERE option_id = (SELECT option_id FROM votes WHERE voter_id = ? AND target_id = ?)", [current_user, id])
        # p users_vote
        if users_vote != []
            users_vote = users_vote.first['content']
        end

        slim(:"users/voting", locals:{votes: options, vote_for: id, users_vote: users_vote})
    end

end

post('/vote/new/:option_for') do
    content = params['new_option']
    option_for = params['option_for']
    
    # safety för dubletter
    exister = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, option_for])

    if exister.empty?
        db.execute('INSERT INTO options(content, for_user, no_of_votes) VALUES (?,?, 0)', [content, option_for])
        redirect("/users/voting/#{option_for}")
    else
        session[:error] = "Option already exists, go vote for it!"
        redirect('/error')
    end

    # option_id = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, option_for])[0]['option_id'] 
end

post('/vote/:vote_for/:option_id') do
    current_user = session[:id]
    option_id = params['option_id']
    vote_for = params['vote_for']

    exister = db.execute('SELECT option_id FROM votes WHERE voter_id=? AND  target_id=?', [current_user, vote_for])
    
    if exister.length != 0
        old_id = exister[0]['option_id']
        no_of_votes = db.execute('SELECT no_of_votes FROM options WHERE option_id=?', old_id)[0]['no_of_votes']
        
        db.execute('DELETE FROM votes WHERE voter_id=? AND  target_id=?', [current_user, vote_for])
        # removes one vote from option
        db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [no_of_votes-1, old_id])
    end
    db.execute('INSERT INTO votes(voter_id, target_id, option_id) VALUES (?,?,?)', [current_user, vote_for, option_id])


    # counts votes_for
    number = db.execute('SELECT option_id FROM votes WHERE option_id=?', option_id).length
    db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [number, option_id])

    redirect("/users/voting/#{vote_for}")
end

get('/error') do
    p session[:error]
    slim(:error, locals:{error_message: session[:error]})
end
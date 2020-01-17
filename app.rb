require "sinatra"
require "slim"
require "bcrypt"
require "SQLite3"

enable :sessions

db = SQLite3::Database.new('database/database.db')
db.results_as_hash = true

get('/') do
    slim(:index)
end

post('/sign_up') do
    username = params["username"]
    password = params["password"]
    confirm_password = params["c_password"]

    result = db.execute("SELECT id FROM users WHERE username=?", username)

    if result.empty?
        if password == confirm_password
            if password.length >= 4
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                session[:id] = db.execute('SELECT id FROM users WHERE username=?', username)
                redirect('users/first_login')
            else
                session[:error] = "Password is too short"
                redirect('/error')
            end
        end
        session[:error] = "Passwords don't match"
        redirect('/error')
    else
        session[:error] = "User already exists"
        redirect('/error')
    end
end

get('/users/first_login') do 
    slim(:"users/first_login")
end

post('/users/complete_profile') do 
    firstname = params["new_name"].downcase
    class_name = params["class"].downcase

    db.execute("UPDATE users SET name=?, class_name=? WHERE id=?", [firstname, class_name, session[:id]])
    # ???
    redirect('/users/home')
end

post("/login") do
    username = params["username"]
    password = params["password"]

    result = db.execute("SELECT id, password_digest FROM users WHERE username = ?", username)
    if result.empty?    
        session[:error] = "Invalid credentials"
        redirect('/error')
    else
        user_id = result.first["id"]
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            session[:id] = db.execute('SELECT id FROM users WHERE username=?', username)
            redirect("/users/home")
        else
            session[:error] = "Wrong password"
            redirect('/error')
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
        p session[:id]
        current_user = session[:id][0]["id"]
        current_class = db.execute('SELECT class_name FROM users WHERE id=?', current_user)[0]["class_name"]

        users = db.execute('SELECT * FROM users LEFT JOIN options ON users.id = options.for_user WHERE class_name=? AND for_user !=?', [current_class.to_s, current_user])
        # options = db.execute('SELECT * FROM options WHERE for_user=?')
        slim(:"users/home", locals:{users: users})
    end
end

get('/error') do
    slim(:error, locals:{error_message: session[:error]})
end